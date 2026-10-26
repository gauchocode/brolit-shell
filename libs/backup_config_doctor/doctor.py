#!/usr/bin/env python3
# Author: GauchoCode
# Version: 0.2.0
"""Definition-only doctor. All externally visible strings are fixed catalog data."""

import datetime
import json
import os
import re
import resource
import signal
import stat
import sys
import uuid

# MAX_BYTES, HOOK_KEYS and RETENTION_KEYS mirror libs/backup_observation/
# borgmatic_profile.py on purpose (equality is tested) instead of importing it:
# the doctor must not depend on the observer's pinned wire contract, and its
# TOKEN grammar is deliberately stricter than the observer's.
MAX_BYTES = 262144
MAX_FILES = 64
MAX_EVENTS = 8192
MAX_DEPTH = 24
MIN_PARSER = (5, 4)
DEADLINE_SECONDS = 10
LOCAL_FS = frozenset(('ext2', 'ext3', 'ext4', 'xfs', 'btrfs', 'overlay',
                      'tmpfs', 'zfs', 'rootfs'))
TOP_KEYS = frozenset('constants source_directories repositories exclude_patterns '
                     'exclude_caches exclude_if_present one_file_system '
                     'compression encryption_passcommand archive_name_format '
                     'match_archives keep_within keep_secondly keep_minutely '
                     'keep_hourly keep_daily keep_weekly keep_monthly keep_yearly '
                     'before_backup after_backup on_error checks check_last '
                     'mysql_databases mariadb_databases postgresql_databases'.split())
DB_KEYS = ('mysql_databases', 'mariadb_databases', 'postgresql_databases')
HOOK_KEYS = ('before_backup', 'after_backup', 'on_error')
RETENTION_KEYS = ('keep_within', 'keep_secondly', 'keep_minutely', 'keep_hourly',
                  'keep_daily', 'keep_weekly', 'keep_monthly', 'keep_yearly')
CHECK_NAMES = frozenset('repository archives data extract spot disabled'.split())
# Borg runtime placeholders, accepted only in archive naming/matching fields.
BORG_PLACEHOLDER = re.compile(r'\{(now|utcnow|hostname|fqdn|reverse-fqdn|user|pid|uuid4|'
                              r'borgversion|borgmajor|borgminor|borgpatch)(:[^{}$\n]*)?\}')
PLACEHOLDER_FIELDS = frozenset(('archive_name_format', 'match_archives'))
# Hook programs are never inspected. Bodies naming databases or Borgmatic
# configuration locations/readers may consume the configuration directly.
HOOK_INTENT = re.compile(r'database|/etc/borgmatic|\.config/borgmatic|borgmatic(?:/|\.d\b)|'
                         r'config\.ya?ml\b|\bborgmatic\s+(?:config|validate|-c|--config)\b',
                         re.IGNORECASE)
# Findings meaning a profile is not fully analyzable (it may include or merge
# other profiles' constants): any such profile suppresses every proposal.
UNPARSED = frozenset(('unsupported_profile', 'yaml_invalid', 'duplicate_key'))
DISCOVERY = (('/etc/borgmatic', True, 'etc_borgmatic'),
             ('/etc/borgmatic.d', False, 'etc_borgmatic_d'),
             ('/root/.config/borgmatic', True, 'root_config_borgmatic'),
             ('/root/.config/borgmatic.d', False, 'root_config_borgmatic_d'))
PROFILE_NAME = re.compile(r'[A-Za-z0-9._-]{1,128}')
TOKEN = re.compile(r'\{([A-Za-z_][A-Za-z0-9_]*)\}')
ENV = re.compile(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*')
RUNTIME_NAMES = frozenset('now utcnow hostname fqdn reverse-fqdn user pid uuid4 '
                          'borgversion borgmajor borgminor borgpatch '
                          'configuration_filename repository archive'.split())
MESSAGES = {
    'yaml_invalid': 'Configuration is not valid supported YAML.',
    'duplicate_key': 'Duplicate mapping keys are not supported.',
    'unsupported_profile': 'Input uses constructs outside the static profile.',
    'inspection_incomplete': 'Inspection could not establish complete evidence.',
    'discovery_unsupported': 'Discovery contains unsupported entries or shapes.',
    'filesystem_unsupported': 'Filesystem identity or locality is not supported.',
    'unresolved_constant': 'A constant reference cannot be resolved statically.',
    'constant_cycle': 'Constant references contain a cycle.',
    'environment_dependency_unavailable': 'Process environment availability is not established.',
    'source_path_missing': 'An authorized local source path is absent.',
    'source_path_unknown': 'Source path existence or locality is not established.',
    'database_mapping_ambiguous': 'Database and project correspondence needs operator review.',
    'hook_intent_unknown': 'Hook commands may read configuration outside static analysis.',
    'unused_constant_candidate': 'An unused database constant blocks static resolution.',
    'manual_review_required': 'A safe proposal cannot be established automatically.',
    'parser_unavailable': 'The tested safe parser dependency is unavailable.',
    'invalid_invocation': 'Invocation is outside the supported command contract.',
}


class Refusal(Exception):
    """Internal fixed finding, never raw parser or filesystem errors."""

    def __init__(self, code, state='unsupported'):
        self.code, self.state = code, state


class InspectionTimeout(BaseException):
    """Wall-clock budget exhausted. Deliberately not an Exception/Refusal so
    per-profile and per-probe handlers can never relabel it."""


def alarm_expired(_signum, _frame):
    raise InspectionTimeout()


class ConstantExpander:
    """Static constant expansion: every constant is resolved once (memoized),
    and all expansions of one profile share a single character budget, so a
    crafted constant graph cannot amplify CPU or memory. None means unknown
    (over budget or cyclic)."""

    def __init__(self, constants, budget=4 * MAX_BYTES):
        self.constants, self.remaining = constants, budget
        self.memo, self.active = {}, set()

    def expand(self, text):
        return None if self.remaining < 0 else self._substitute(text)

    def _substitute(self, text):
        parts, last = [], 0
        for match in TOKEN.finditer(text):
            parts.append(text[last:match.start()])
            last = match.end()
            if match[1] not in self.constants:
                parts.append(match[0])
                continue
            value = self._resolve(match[1])
            if value is None:
                return None
            parts.append(value)
        parts.append(text[last:])
        # Size is checked before joining: nothing over budget is materialized.
        size = sum(map(len, parts))
        if size > self.remaining:
            self.remaining = -1
            return None
        self.remaining -= size
        return ''.join(parts)

    def _resolve(self, name):
        if name in self.memo:
            return self.memo[name]
        if name in self.active or self.remaining < 0:
            return None
        self.active.add(name)
        value = self._substitute(str(self.constants[name]))
        self.active.discard(name)
        self.memo[name] = value
        return value


def effective_capabilities():
    """CapEff of this process, or None when it cannot be established."""
    try:
        with open('/proc/self/status', 'rb') as stream:
            status = stream.read(65536)
        for line in status.splitlines():
            if line.startswith(b'CapEff:'):
                return int(line.split()[1], 16)
    except (OSError, ValueError, IndexError):
        pass
    return None


def finding(code):
    return {'code': code, 'message': MESSAGES[code]}


def handle(prefix):
    return prefix + uuid.uuid4().hex


def parser_version(yaml):
    """Major/minor of the safe parser; malformed versions are unsupported."""
    try:
        version = tuple(int(part) for part in yaml.__version__.split('.')[:2])
    except (AttributeError, ValueError):
        raise Refusal('parser_unavailable') from None
    if len(version) != 2 or version < MIN_PARSER:
        raise Refusal('parser_unavailable')
    return version


def parser_dependency():
    # Same profile as the observer parser: PyYAML >= 5.4 (fleet 5.4.1/6.0.x).
    try:
        import yaml
    except ImportError:
        raise Refusal('parser_unavailable') from None
    parser_version(yaml)
    return yaml


def mount_table():
    # Linux kernel metadata only. Do not use stat/realpath on discovered mounts.
    with open('/proc/self/mountinfo', 'rb') as stream:
        raw = stream.read(1048577)
    if len(raw) > 1048576:
        raise Refusal('filesystem_unsupported')
    rows = []
    # Non-ASCII mount points must not fail the run; paths compare as fs-decoded str.
    for line in raw.decode('utf-8', 'surrogateescape').splitlines():
        left, right = line.split(' - ', 1)
        point = re.sub(r'\\([0-7]{3})', lambda m: chr(int(m[1], 8)), left.split()[4])
        rows.append((point, right.split()[0]))
    if not any(point == '/' for point, _ in rows):
        raise Refusal('filesystem_unsupported')
    return rows


class SafeFS:
    """Checked mount policy BEFORE descriptor-relative non-following access."""

    def __init__(self, mounts):
        self.mounts = mounts

    def local(self, path):
        # Reject *any* unknown boundary in the ancestry, even if a more specific
        # mount is local. Never trigger automount to discover its target type.
        return all(fs in LOCAL_FS for point, fs in self.mounts
                   if point == '/' or path == point or path.startswith(point.rstrip('/') + '/'))

    def open(self, path, directory=False):
        if not path.startswith('/') or any(p in ('.', '..', '') for p in path.split('/')[1:]):
            raise Refusal('filesystem_unsupported')
        if not self.local('/'):
            raise Refusal('filesystem_unsupported')
        fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NONBLOCK)
        current = ''
        try:
            parts = path.split('/')[1:]
            for i, part in enumerate(parts):
                current += '/' + part
                if not self.local(current):
                    raise Refusal('filesystem_unsupported')
                is_dir = i < len(parts) - 1 or directory
                flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
                # No fallback without O_NOATIME: refuse insufficient ownership
                # rather than causing access-time metadata writes on inputs.
                if i == len(parts) - 1:
                    flags |= os.O_NOATIME
                if is_dir:
                    flags |= os.O_DIRECTORY
                # Refuse non-regular entries before open (no FIFO/device reads).
                meta = os.stat(part, dir_fd=fd, follow_symlinks=False)
                if not (stat.S_ISDIR(meta.st_mode) if is_dir else stat.S_ISREG(meta.st_mode)):
                    raise Refusal('filesystem_unsupported')
                child = os.open(part, flags, dir_fd=fd)
                opened = os.fstat(child)
                if (meta.st_dev, meta.st_ino) != (opened.st_dev, opened.st_ino):
                    os.close(child)
                    raise Refusal('filesystem_unsupported')
                # Swap before closing: a timeout between the two statements must
                # never make the handler below close an already-closed fd.
                parent, fd = fd, child
                os.close(parent)
            return fd
        except BaseException:
            os.close(fd)
            raise

    def read(self, path):
        fd = self.open(path)
        try:
            before = os.fstat(fd)
            if before.st_nlink != 1 or before.st_size > MAX_BYTES:
                raise Refusal('filesystem_unsupported')
            raw = os.read(fd, MAX_BYTES + 1)
            after = os.fstat(fd)
            if (len(raw) > MAX_BYTES or before.st_size != len(raw)
                    or (before.st_size, before.st_mtime_ns, before.st_ctime_ns)
                    != (after.st_size, after.st_mtime_ns, after.st_ctime_ns)):
                raise Refusal('inspection_incomplete', 'unknown')
            return raw
        finally:
            os.close(fd)


def parse(raw, yaml):
    try:
        text = raw.decode('utf-8')
        depth = 0
        for count, event in enumerate(yaml.parse(text)):
            if count >= MAX_EVENTS:
                raise Refusal('unsupported_profile')
            if isinstance(event, yaml.AliasEvent) or getattr(event, 'anchor', None):
                raise Refusal('unsupported_profile')
            if getattr(event, 'tag', None) is not None:
                raise Refusal('unsupported_profile')
            if isinstance(event, (yaml.MappingStartEvent, yaml.SequenceStartEvent)):
                depth += 1
                if depth > MAX_DEPTH:
                    raise Refusal('unsupported_profile')
            if isinstance(event, (yaml.MappingEndEvent, yaml.SequenceEndEvent)):
                depth -= 1
        root = yaml.compose(text, Loader=yaml.SafeLoader)
        scalar_tags = {'tag:yaml.org,2002:' + tag for tag in ('str', 'int', 'float', 'bool', 'null')}

        def check(node):
            if isinstance(node, yaml.MappingNode):
                seen = set()
                for key, value in node.value:
                    if not isinstance(key, yaml.ScalarNode) or key.tag != 'tag:yaml.org,2002:str':
                        raise Refusal('unsupported_profile')
                    if key.value in seen:
                        raise Refusal('duplicate_key', 'invalid')
                    seen.add(key.value)
                    if any(char in key.value for char in '{}$'):
                        raise Refusal('unsupported_profile')
                    check(value)
            elif isinstance(node, yaml.SequenceNode):
                for value in node.value:
                    check(value)
            elif not isinstance(node, yaml.ScalarNode) or node.tag not in scalar_tags:
                raise Refusal('unsupported_profile')

        if not isinstance(root, yaml.MappingNode):
            raise Refusal('unsupported_profile')
        check(root)
        doc = yaml.safe_load(text)
        return text, root, doc
    except (yaml.YAMLError, UnicodeError, ValueError, RecursionError):
        raise Refusal('yaml_invalid', 'invalid') from None


def analyze(raw, yaml, fs, test_root=None, simulate=True):
    result = {'profile_id': handle('p_'), 'configuration_state': 'unknown',
              'complete': False, 'findings': [], 'proposal': None}
    codes = set()

    def add(code):
        codes.add(code)

    try:
        text, root, doc = parse(raw, yaml)
        if set(doc) - TOP_KEYS:
            add('unsupported_profile')
        constants = doc.get('constants', {})
        if not isinstance(constants, dict) or len(constants) > 128:
            raise Refusal('unsupported_profile')
        for key, value in constants.items():
            if (not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key)
                    or type(value) not in (str, int, float)):
                raise Refusal('unsupported_profile')

        references = set()
        edges = {}
        env_locations = set()

        expander = ConstantExpander(constants)

        def hook_intent_unknown(body):
            # The command word must be literal. The guard sees the raw body
            # (a constant name such as {database_name} must not hide intent)
            # and the expanded body (a constant value must not hide a reader).
            words = body.split()
            if not words or any(char in words[0] for char in '{}$'):
                return True
            if HOOK_INTENT.search(body):
                return True
            expanded = expander.expand(body)
            return expanded is None or bool(HOOK_INTENT.search(expanded))

        def inspect_string(value, location):
            if not isinstance(value, str):
                return set()
            if location[:1] and location[0] in PLACEHOLDER_FIELDS:
                # A bare {name} that is also a constant stays a constant
                # reference: Borgmatic interpolates constants first.
                value = BORG_PLACEHOLDER.sub(
                    lambda m: m[0] if m[2] is None and m[1] in constants else '', value)
            possible_refs = set(TOKEN.findall(value))
            # Environment braces are not constant references.
            stripped = ENV.sub('', value)
            refs = set(TOKEN.findall(stripped))
            if any(char in TOKEN.sub('', stripped) for char in '{}$'):
                add('unsupported_profile')
            if ENV.search(value):
                env_locations.add(location)
                add('environment_dependency_unavailable')
            if refs - constants.keys():
                add('unresolved_constant')
                if (refs - constants.keys()) & RUNTIME_NAMES:
                    # These may be Borg/Borgmatic runtime placeholders, not
                    # invalid user constants. Do not simulate their semantics.
                    add('unsupported_profile')
            # Ordering of environment and constant expansion differs across
            # versions. A brace name inside an environment expression can
            # therefore establish possible USE, never proof of non-use.
            references.update(possible_refs)
            return possible_refs & constants.keys()

        def walk(value, location):
            if isinstance(value, dict):
                for key, child in value.items():
                    walk(child, location + (key,))
            elif isinstance(value, list):
                for child in value:
                    walk(child, location)
            else:
                refs = inspect_string(value, location)
                if len(location) == 2 and location[0] == 'constants':
                    edges[location[1]] = refs

        walk(doc, ())
        visited, active = set(), set()

        def visit(key):
            if key in active:
                add('constant_cycle')
                return
            if key in visited:
                return
            active.add(key)
            for ref in edges.get(key, set()):
                visit(ref)
            active.remove(key)
            visited.add(key)

        for key in constants:
            visit(key)
        for key in DB_KEYS:
            if key in doc:
                add('database_mapping_ambiguous')
        repositories = doc.get('repositories')
        if not isinstance(repositories, list) or not repositories:
            add('unsupported_profile')
        else:
            for repo in repositories:
                if isinstance(repo, str):
                    continue
                if (not isinstance(repo, dict) or set(repo) - {'path', 'label'}
                        or not isinstance(repo.get('path'), str)
                        or ('label' in repo and not isinstance(repo['label'], str))):
                    add('unsupported_profile')
        for hook in HOOK_KEYS:
            if hook in doc and (not isinstance(doc[hook], list)
                               or any(not isinstance(v, str) for v in doc[hook])):
                add('unsupported_profile')
            elif any(hook_intent_unknown(body) for body in doc.get(hook) or ()):
                # Bodies were scanned for references above; programs they run
                # are not. Residual risk is declared in the limitations.
                add('hook_intent_unknown')
        checks = doc.get('checks', [])
        if not isinstance(checks, list) or any(
                not isinstance(check, dict) or set(check) - {'name', 'frequency', 'max_duration', 'only_run_on'}
                or not isinstance(check.get('name'), str) or check['name'] not in CHECK_NAMES
                or ('frequency' in check and not isinstance(check['frequency'], str))
                or ('max_duration' in check and type(check['max_duration']) is not int)
                or ('only_run_on' in check and (not isinstance(check['only_run_on'], list)
                                                or any(not isinstance(v, str) for v in check['only_run_on'])))
                for check in checks):
            add('unsupported_profile')
        if 'check_last' in doc and (type(doc['check_last']) is not int or doc['check_last'] < 0):
            add('unsupported_profile')
        if doc.get('encryption_passcommand'):
            # Like hooks, passcommand can read the original config directly.
            add('unsupported_profile')
        string_fields = ('compression', 'encryption_passcommand', 'archive_name_format',
                         'match_archives', 'exclude_if_present', 'keep_within')
        list_fields = ('exclude_patterns',)
        bool_fields = ('exclude_caches', 'one_file_system')
        for key in string_fields:
            if key in doc and not isinstance(doc[key], str):
                add('unsupported_profile')
        for key in list_fields:
            if key in doc and (not isinstance(doc[key], list)
                               or any(not isinstance(v, str) for v in doc[key])):
                add('unsupported_profile')
        for key in bool_fields:
            if key in doc and type(doc[key]) is not bool:
                add('unsupported_profile')
        for key in RETENTION_KEYS[1:]:
            if key in doc:
                if type(doc[key]) is not int or doc[key] < 0:
                    add('unsupported_profile')
        sources = doc.get('source_directories', [])
        if not isinstance(sources, list) or any(not isinstance(v, str) for v in sources):
            add('unsupported_profile')
        else:
            for source in sources:
                # No production source probing without an approved locality
                # policy. Test mode's /sources is explicitly fixture-local.
                if (test_root is None or not source.startswith('/sources/')
                        or any(c in source for c in '{}$*?[]')
                        or any(p in ('', '.', '..') for p in source.split('/')[1:])):
                    add('source_path_unknown')
                    continue
                try:
                    fd = fs.open(test_root + source, directory=True)
                    os.close(fd)
                except FileNotFoundError:
                    add('source_path_missing')
                except (OSError, Refusal):
                    add('source_path_unknown')

        candidate = ('database' in constants and 'database' not in references
                     and ('constants', 'database') in env_locations)
        if candidate:
            add('unused_constant_candidate')
        resolved = {'environment_dependency_unavailable', 'unused_constant_candidate'}
        # Source-path evidence is independent of removing an unused constant: it
        # stays reported (and keeps the profile incomplete) but does not block.
        blockers = codes - resolved - {'source_path_unknown', 'source_path_missing'}
        eligible = (candidate and not blockers
                    and env_locations == {('constants', 'database')})
        if eligible and simulate:
            prospective = minimal_deletion(text, root, yaml)
            if prospective is not None:
                checked = analyze(prospective, yaml, fs, test_root, simulate=False)
                # The deletion must resolve exactly the constant's findings and
                # introduce nothing new.
                if {f['code'] for f in checked['findings']} - {'manual_review_required'} == codes - resolved:
                    result['proposal'] = {
                        'proposal_id': handle('i_'), 'rule': 'unused-database-constant',
                        'rule_version': 1, 'operation': 'remove unreferenced constants.database',
                        'authority': 'informational_only', 'dry_run': 'memory_only_validated',
                    }
        if (codes or 'database' in constants) and result['proposal'] is None:
            add('manual_review_required')
        if 'unsupported_profile' in codes:
            state = 'unsupported'
        elif codes & {'database_mapping_ambiguous', 'source_path_unknown', 'hook_intent_unknown'}:
            state = 'ambiguous'
        elif codes & {'unresolved_constant', 'constant_cycle', 'source_path_missing'}:
            state = 'invalid'
        elif 'environment_dependency_unavailable' in codes:
            state = 'unknown'
        else:
            state = 'valid_for_supported_static_checks'
        result['configuration_state'] = state
        result['complete'] = not bool(codes & {'unsupported_profile', 'source_path_unknown',
                                              'database_mapping_ambiguous', 'hook_intent_unknown',
                                              'environment_dependency_unavailable'})
    except Refusal as error:
        add(error.code)
        add('manual_review_required')
        result['configuration_state'] = error.state
    result['findings'] = [finding(code) for code in sorted(codes)]
    return result


def minimal_deletion(text, root, yaml):
    """Delete only one whole simple block-entry line; preserve all other bytes."""
    for key, constants in root.value:
        if key.value != 'constants' or not isinstance(constants, yaml.MappingNode) or constants.flow_style:
            continue
        for name, value in constants.value:
            if name.value != 'database' or not isinstance(value, yaml.ScalarNode):
                continue
            if name.start_mark.line != value.end_mark.line or value.style in ('|', '>'):
                return None
            lines = text.splitlines(keepends=True)
            line = lines[name.start_mark.line]
            if not re.match(r'^ +database\s*:', line):
                return None
            # Removing the last mapping entry would leave constants:null.
            if len(constants.value) < 2:
                return None
            return ''.join(lines[:name.start_mark.line] + lines[name.start_mark.line + 1:]).encode('utf-8')
    return None


def discover(fs, prefix):
    """Fixed default locations only; never $HOME/$XDG or caller-supplied paths."""
    entries, codes = [], set()
    for directory, single, location in DISCOVERY:
        directory = prefix + directory
        try:
            fd = fs.open(directory, directory=True)
        except FileNotFoundError:
            continue
        except (OSError, Refusal):
            codes.add('filesystem_unsupported')
            continue
        try:
            # Includes all possible names in the single-config directory rather
            # than silently ignoring an alternate suffix/nested configuration.
            # Iteration itself is bounded; never materialize an unbounded
            # listdir before enforcing the file-count budget.
            with os.scandir(fd) as found:
                for count, entry in enumerate(found):
                    if count >= MAX_FILES:
                        codes.add('inspection_incomplete')
                        break
                    name = entry.name
                    if (single and name != 'config.yaml') or (not single and not name.endswith(('.yml', '.yaml'))):
                        codes.add('discovery_unsupported')
                        continue
                    if len(entries) >= MAX_FILES:
                        codes.add('inspection_incomplete')
                        break
                    # No DirEntry.is_* methods (they may stat the target).
                    entries.append((directory + '/' + name, location, name))
        except (OSError, Refusal):
            codes.add('filesystem_unsupported')
        finally:
            os.close(fd)
    return sorted(entries), codes


def envelope():
    return {
        'protocol_version': 'backup-config-doctor/1', 'doctor_version': '0.2.0',
        'capability_profile': 'flat-static-v1', 'parser_profile': None,
        'inspected_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'outcome': 'unsupported', 'complete': False, 'truncated': False,
        'findings': [], 'profiles': [],
        'limitations': ['static_checks_only', 'borgmatic_semantics_uncertified',
                        'explicit_config_paths_not_inspected', 'hook_programs_not_inspected',
                        'no_environment_resolution', 'no_production_source_locality_policy',
                        'no_execution_or_restore_evidence', 'no_apply_authority'],
    }


def refused_profile(code):
    return {'profile_id': handle('p_'), 'configuration_state': 'unsupported', 'complete': False,
            'findings': [finding(code), finding('manual_review_required')], 'proposal': None}


def inspect(argv):
    result = envelope()
    test_root = None
    if argv == ['inspect']:
        if os.geteuid() != 0:
            raise Refusal('invalid_invocation')
        prefix = ''
    elif len(argv) == 3 and argv[:2] == ['--test-mode', 'inspect']:
        # Unprivileged fixtures only: as root (or with any effective capability,
        # e.g. CAP_DAC_READ_SEARCH) this would be an arbitrary-path reader.
        if os.geteuid() == 0 or effective_capabilities() != 0 or not argv[2].startswith('/'):
            raise Refusal('invalid_invocation')
        test_root = argv[2]
        prefix = test_root
    else:
        raise Refusal('invalid_invocation')
    yaml = parser_dependency()
    result['parser_profile'] = 'pyyaml-safe/%d.%d' % parser_version(yaml)
    fs = SafeFS(mount_table())
    if test_root is not None:
        if fs.read(test_root + '/.backup-config-doctor-fixture') != b'isolated-fixture\n':
            raise Refusal('invalid_invocation')
    entries, codes, timed_out = [], set(), False
    try:
        entries, found = discover(fs, prefix)
        codes |= found
        for path, location, name in entries:
            if not PROFILE_NAME.fullmatch(name):
                # Unprojectable name: counted, never analyzed or echoed.
                name = None
                profile = refused_profile('discovery_unsupported')
            else:
                try:
                    profile = analyze(fs.read(path), yaml, fs, test_root)
                except (OSError, Refusal):
                    profile = refused_profile('filesystem_unsupported')
                except MemoryError:
                    # One oversized profile must not discard every other result.
                    profile = refused_profile('inspection_incomplete')
                    codes.add('inspection_incomplete')
            result['profiles'].append({'file': name, 'location': location, **profile})
            found_codes = {f['code'] for f in profile['findings']}
            # Unreadable entries and profiles that are not fully analyzable (they
            # may include or merge another profile's constants) make every
            # profile's reference analysis incomplete, including their own.
            if found_codes & ({'filesystem_unsupported', 'discovery_unsupported'} | UNPARSED):
                codes.add('discovery_unsupported')
    except InspectionTimeout:
        # Keep fully analyzed profiles; the interrupted one is dropped.
        timed_out = True
        codes.add('inspection_incomplete')
    if not entries:
        codes.add('inspection_incomplete')
    # Discovery incompleteness must also suppress otherwise local proposals.
    if codes:
        for profile in result['profiles']:
            profile['proposal'] = None
            if not any(f['code'] == 'manual_review_required' for f in profile['findings']):
                profile['findings'].append(finding('manual_review_required'))
    result['findings'] = [finding(code) for code in sorted(codes)]
    result['truncated'] |= 'inspection_incomplete' in codes
    result['complete'] = not codes and all(p['complete'] for p in result['profiles'])
    if result['complete']:
        result['outcome'] = 'complete'
    elif result['profiles']:
        result['outcome'] = 'partial'
    elif timed_out:
        result['outcome'] = 'failed'
    else:
        result['outcome'] = 'unsupported'
    return result


def failed(truncated=False):
    result = envelope()
    result.update(outcome='failed', truncated=truncated,
                  findings=[finding('inspection_incomplete')])
    return result


def guarded(argv):
    """Map every inspection error to fixed findings. A timeout raised while
    these handlers run escapes to main(), which reports it."""
    result = envelope()
    try:
        return inspect(argv)
    except Refusal as error:
        result['findings'] = [finding(error.code)]
        result['outcome'] = 'unsupported' if error.state == 'unsupported' else 'failed'
    except InspectionTimeout:
        # Expired outside the profile loop (parser, mount table, discovery setup).
        result = failed(truncated=True)
    except BaseException:
        # Deliberately suppress parser/OS details and secret-bearing exceptions.
        result = failed()
    return result


def main():
    # The alarm is one-shot. If it lands while the inner handler maps an error,
    # the outer handler reports it, and it cannot fire again after that, so
    # exactly one JSON object is always printed.
    try:
        try:
            # A root core dump would contain configuration plaintext.
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
            # No disk fallback. Existing lower limits are never increased.
            for limit, maximum in ((resource.RLIMIT_AS, 268435456), (resource.RLIMIT_CPU, 12)):
                soft, hard = resource.getrlimit(limit)
                resource.setrlimit(limit, (min(soft, maximum) if soft != resource.RLIM_INFINITY else maximum, hard))
            signal.signal(signal.SIGALRM, alarm_expired)
            signal.alarm(DEADLINE_SECONDS)
            result = guarded(sys.argv[1:])
        except BaseException as error:
            result = failed(truncated=isinstance(error, InspectionTimeout))
        signal.alarm(0)
    except BaseException as error:
        # Reached only if the inner handler itself failed: disarm first so a
        # still-pending alarm cannot interrupt this last mapping.
        signal.alarm(0)
        result = failed(truncated=isinstance(error, InspectionTimeout))
    rendered = json.dumps(result, separators=(',', ':'), allow_nan=False)
    if len(rendered.encode('utf-8')) > MAX_BYTES:
        rendered = json.dumps(failed(truncated=True), separators=(',', ':'))
    sys.stdout.write(rendered + '\n')


if __name__ == '__main__':
    main()
