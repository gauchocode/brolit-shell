#!/usr/bin/env python3
# Author: GauchoCode
# Version: 0.2.0
"""Offline synthetic fixtures. Only this test process creates fixture files."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('doctor', ROOT / 'libs/backup_config_doctor/doctor.py')
doctor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doctor)
YAML = None
TEMPLATES = ROOT / 'config/borg'
# The generator always appends repositories like this (libs/local/borg_config_helper.sh).
REPOSITORY = (b'repositories:\n'
              b'    - path: "ssh://{user_1}@{server_1}:{port_1}/home/applications/{group}/{hostname}'
              b'/projects-online/site/{project}"\n'
              b'      label: "storage-{user_1}"\n')


def template(name, database=None):
    """A Brolit template as generated: synthetic constants plus repositories."""
    raw = (TEMPLATES / f'borgmatic.template-{name}.yml').read_bytes().rstrip(b'\n') + b'\n' + REPOSITORY
    assert raw.startswith(b'constants:\n')
    if database is not None:
        raw = raw.replace(b'constants:\n', b'constants:\n    database: ' + database + b'\n', 1)
    return raw


def setUpModule():
    global YAML
    required = os.environ.get('DOCTOR_REQUIRE_PARSER') == '1'
    if os.geteuid() == 0:
        # Test mode refuses root by design (it would be an arbitrary-path reader).
        if required:
            raise AssertionError('doctor tests must run unprivileged')
        raise unittest.SkipTest('doctor tests must run unprivileged')
    try:
        YAML = doctor.parser_dependency()
    except doctor.Refusal:
        if required:
            raise AssertionError('supported PyYAML (>= 5.4) required but unavailable') from None
        raise unittest.SkipTest('supported PyYAML (>= 5.4) unavailable; do not install') from None


BASE = b'repositories:\n  - path: /fixture-repository\n    label: fixture\nsource_directories: []\n'
SUPPORT = (b'constants:\n  project: support\n  database: "${CANARY_DATABASE}" # never expose\n'
           + BASE)


class DoctorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='doctor-')
        self.root = Path(self.temp.name)
        (self.root / '.backup-config-doctor-fixture').write_bytes(b'isolated-fixture\n')
        (self.root / 'etc/borgmatic.d').mkdir(parents=True)
        self.fs = doctor.SafeFS(doctor.mount_table())

    def tearDown(self):
        self.temp.cleanup()

    def analyze(self, raw, test=True):
        return doctor.analyze(raw, YAML, self.fs, str(self.root) if test else None)

    def codes(self, result):
        return {entry['code'] for entry in result['findings']}

    def profile(self, raw=BASE, name='fixture.yaml'):
        path = self.root / 'etc/borgmatic.d' / name
        path.write_bytes(raw)
        return path

    def cli(self, *args):
        completed = subprocess.run(['bash', str(ROOT / 'backup_config_doctor.sh'), *args],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(completed.stderr, b'')
        self.assertLessEqual(len(completed.stdout), doctor.MAX_BYTES + 1)
        return json.loads(completed.stdout)

    def test_minimal_memory_proposal(self):
        result = self.analyze(SUPPORT)
        self.assertEqual(result['proposal']['operation'], 'remove unreferenced constants.database')
        self.assertEqual(result['proposal']['authority'], 'informational_only')
        self.assertIn('unused_constant_candidate', self.codes(result))
        text, root, _ = doctor.parse(SUPPORT, YAML)
        prospective = doctor.minimal_deletion(text, root, YAML)
        self.assertEqual(prospective, SUPPORT.replace(
            b'  database: "${CANARY_DATABASE}" # never expose\n', b''))
        self.assertEqual(self.analyze(prospective)['configuration_state'],
                         'valid_for_supported_static_checks')

    def test_valid_flat_custom_and_standalone(self):
        for raw in (BASE, BASE + b'keep_daily: 7\ncompression: zstd\nexclude_patterns: [cache]\n',
                    BASE + b'constants: {hostname: server}\n'):
            with self.subTest(raw=raw):
                self.assertEqual(self.analyze(raw)['configuration_state'], 'valid_for_supported_static_checks')
        db = self.analyze(BASE + b'mysql_databases: [{name: fixture}]\n')
        self.assertIn('database_mapping_ambiguous', self.codes(db))
        self.assertIsNone(db['proposal'])

    def test_yaml_rejections(self):
        cases = [
            (b'CANARY_SECRET: [', 'yaml_invalid'),
            (BASE + b'keep_daily: 1\nkeep_daily: 2\n', 'duplicate_key'),
            (BASE + b'constants: {project: a, project: b}', 'duplicate_key'),
            (BASE + b'compression: !CANARY_SECRET value', 'unsupported_profile'),
            (BASE + b'compression: !!str zstd', 'unsupported_profile'),
            (BASE + b'exclude_patterns: &a [*a]', 'unsupported_profile'),
            (BASE + b'exclude_patterns: &a [cache]', 'unsupported_profile'),
            (BASE + b'constants: {<<: {project: a}}', 'unsupported_profile'),
            (BASE + b'include: CANARY_SECRET', 'unsupported_profile'),
            (BASE + b'---\nrepositories: []', 'yaml_invalid'),
            (BASE + b'exclude_patterns: [' + b'[' * 26 + b'x' + b']' * 27, 'unsupported_profile'),
            (BASE + b'exclude_patterns: [' + b'x,' * 8300 + b']', 'unsupported_profile'),
            (BASE + b'constants: {project: [nested]}', 'unsupported_profile'),
            (BASE + b'keep_daily: {include: secret}', 'unsupported_profile'),
            (BASE + b'compression: 2026-10-25', 'unsupported_profile'),
            (b'\xff', 'yaml_invalid'),
        ]
        for raw, code in cases:
            with self.subTest(code=code, raw=raw[:80]):
                result = self.analyze(raw)
                self.assertIn(code, self.codes(result))
                self.assertIsNone(result['proposal'])
                self.assertNotIn('CANARY_SECRET', json.dumps(result))

    def test_reference_and_environment_analysis(self):
        cases = [
            (b'compression: "{missing}"\n', 'unresolved_constant'),
            (b'compression: "${CANARY_SECRET}"\n', 'environment_dependency_unavailable'),
            (b'compression: "$CANARY_SECRET"\n', 'environment_dependency_unavailable'),
            (b'compression: "${DB:-fallback}"\n', 'unsupported_profile'),
            (b'compression: "{{database}}"\n', 'unsupported_profile'),
        ]
        for extra, code in cases:
            result = self.analyze(SUPPORT + extra)
            self.assertIn(code, self.codes(result))
            self.assertIsNone(result['proposal'])
        for extra in (b'compression: "{database}"\n',
                      b'compression: "${database}"\n',
                      b'before_backup: ["echo {database}"]\n',
                      b'encryption_passcommand: external-reader\n',
                      b'compression: "{now}"\n'):
            self.assertIsNone(self.analyze(SUPPORT + extra)['proposal'])
        # Decision A: inert-looking hooks and Borg placeholders in archive fields
        # no longer block. A hook program that reads the file itself is the
        # declared residual risk (`hook_programs_not_inspected`).
        for extra in (b'before_backup: ["external-reader"]\n',
                      b'archive_name_format: "{now}"\n'):
            self.assertIsNotNone(self.analyze(SUPPORT + extra)['proposal'])
        transitive = SUPPORT.replace(b'  project: support', b'  project: "{database}"')
        self.assertIsNone(self.analyze(transitive)['proposal'])
        cycle = BASE + b'constants: {a: "{b}", b: "{a}"}'
        self.assertIn('constant_cycle', self.codes(self.analyze(cycle)))

    def test_no_preserving_edit_means_manual(self):
        for raw in (BASE + b'constants: {database: "${DB}"}\n',
                    BASE + b'constants:\n  database: "${DB}"\n',
                    BASE + b'constants:\n  project: fixture\n  database: |\n    ${DB}\n'):
            result = self.analyze(raw)
            self.assertIsNone(result['proposal'])
            self.assertIn('manual_review_required', self.codes(result))

    def test_ambiguity_suppresses_proposal(self):
        for extra in (b'mysql_databases: [{name: mysql}]\n',
                      b'mariadb_databases: [{name: proxy}]\n',
                      b'unknown_extension: anything\n'):
            self.assertIsNone(self.analyze(SUPPORT + extra)['proposal'])
        raw = SUPPORT.replace(b'source_directories: []', b'source_directories: [/remote/CANARY_SECRET]')
        with mock.patch.object(os, 'stat', side_effect=AssertionError('source must not be probed')):
            result = self.analyze(raw, test=False)
        # Decision B: reported and incomplete, but independent of the constant.
        self.assertIn('source_path_unknown', self.codes(result))
        self.assertEqual((result['configuration_state'], result['complete']), ('ambiguous', False))
        self.assertIsNotNone(result['proposal'])
        missing = SUPPORT.replace(b'source_directories: []', b'source_directories: [/sources/missing]')
        result = self.analyze(missing)
        self.assertIn('source_path_missing', self.codes(result))
        self.assertIsNotNone(result['proposal'])

    def test_local_source_metadata_and_unsafe_source_no_traversal(self):
        (self.root / 'sources').mkdir()
        (self.root / 'sources/present').mkdir()
        (self.root / 'sources/link').symlink_to('/CANARY_SECRET')
        for source, expected in (('/sources/present', None), ('/sources/missing', 'source_path_missing'),
                                 ('/sources/link', 'source_path_unknown'), ('relative', 'source_path_unknown'),
                                 ('/sources/*', 'source_path_unknown'), ('/sources/../etc', 'source_path_unknown')):
            raw = BASE.replace(b'source_directories: []', f'source_directories: [{source}]'.encode())
            codes = self.codes(self.analyze(raw))
            if expected:
                self.assertIn(expected, codes)
            else:
                self.assertFalse(codes)

    def test_mount_refusal_before_any_target_access(self):
        for fs_type in ('autofs', 'nfs', 'cifs', 'fuse.sshfs', 'unknown'):
            unsafe = doctor.SafeFS([('/', 'ext4'), ('/untrusted', fs_type)])
            original_stat, original_open = os.stat, os.open
            touched = []

            def guard_stat(path, *args, **kwargs):
                touched.append(path)
                return original_stat(path, *args, **kwargs)

            def guard_open(path, *args, **kwargs):
                touched.append(path)
                return original_open(path, *args, **kwargs)

            with mock.patch.object(os, 'stat', guard_stat), mock.patch.object(os, 'open', guard_open):
                with self.assertRaises(doctor.Refusal):
                    unsafe.open('/untrusted/remote/config.yaml')
            self.assertEqual(touched, ['/'])
        # Same guard applies to fixture source metadata, not just config files.
        raw = BASE.replace(b'source_directories: []', b'source_directories: [/sources/remote/file]')
        unsafe = doctor.SafeFS([('/', 'ext4'), (str(self.root / 'sources'), 'autofs')])
        touched = []
        original_stat = os.stat

        def source_guard(path, *args, **kwargs):
            touched.append(path)
            self.assertNotIn(path, ('sources', 'remote', 'file'))
            return original_stat(path, *args, **kwargs)

        with mock.patch.object(os, 'stat', source_guard):
            result = doctor.analyze(raw, YAML, unsafe, str(self.root))
        self.assertIn('source_path_unknown', self.codes(result))
        self.assertNotIn('sources', touched)

    def test_discovery_both_suffixes_single_and_unsupported(self):
        self.profile(BASE, 'one.yml')
        self.profile(BASE, 'two.yaml')
        (self.root / 'etc/borgmatic').mkdir()
        (self.root / 'etc/borgmatic/config.yaml').write_bytes(BASE)
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertEqual(len(result['profiles']), 3)
        self.assertTrue(result['complete'])
        (self.root / 'etc/borgmatic.d/nested').mkdir()
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertFalse(result['complete'])
        self.assertIn('discovery_unsupported', self.codes(result))

    def test_discovery_partial_suppresses_all_proposals(self):
        self.profile(SUPPORT)
        (self.root / 'etc/borgmatic.d/unrecognized.txt').write_bytes(b'')
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertIsNone(result['profiles'][0]['proposal'])

    def test_symlink_ancestors_files_hardlinks_fifo_and_size(self):
        path = self.profile()
        path.unlink()
        path.symlink_to('/CANARY_SECRET')
        self.assertEqual(doctor.inspect(['--test-mode', 'inspect', str(self.root)])['profiles'][0]
                         ['configuration_state'], 'unsupported')
        path.unlink()
        os.mkfifo(path)
        with self.assertRaises(doctor.Refusal):
            self.fs.read(str(path))
        path.unlink()
        path.write_bytes(BASE)
        os.link(path, self.root / 'hardlink')
        with self.assertRaises(doctor.Refusal):
            self.fs.read(str(path))
        (self.root / 'hardlink').unlink()
        path.write_bytes(b'x' * (doctor.MAX_BYTES + 1))
        with self.assertRaises(doctor.Refusal):
            self.fs.read(str(path))
        link = self.root / 'linked-root'
        link.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(doctor.Refusal):
            self.fs.read(str(link / '.backup-config-doctor-fixture'))

    def test_file_count_bound(self):
        for i in range(doctor.MAX_FILES + 5):
            self.profile(BASE, f'{i}.yaml')
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertLessEqual(len(result['profiles']), doctor.MAX_FILES)
        self.assertFalse(result['complete'])
        self.assertTrue(result['truncated'])

    def test_input_access_times_unchanged(self):
        path = self.profile(SUPPORT)
        directory = path.parent
        os.utime(path, ns=(1000000000, path.stat().st_mtime_ns))
        os.utime(directory, ns=(1000000000, directory.stat().st_mtime_ns))
        before_file, before_dir = path.stat(), directory.stat()
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertIsNotNone(result['profiles'][0]['proposal'])
        self.assertEqual(path.stat().st_atime_ns, before_file.st_atime_ns)
        self.assertEqual(directory.stat().st_atime_ns, before_dir.st_atime_ns)
        self.assertEqual(path.stat().st_mtime_ns, before_file.st_mtime_ns)

    def test_dependency_refusal(self):
        with mock.patch.dict(sys.modules, {'yaml': None}):
            with self.assertRaises(doctor.Refusal):
                doctor.parser_dependency()
        for version in ('5.3.1', '4.2', '6', 'garbage', '6.x.1', ''):
            with self.subTest(version=version), mock.patch.object(YAML, '__version__', version):
                with self.assertRaises(doctor.Refusal):
                    doctor.parser_dependency()

    def test_parser_profile_accepts_fleet_versions(self):
        for version, profile in (('5.4', 'pyyaml-safe/5.4'), ('5.4.1', 'pyyaml-safe/5.4'),
                                 ('6.0.1', 'pyyaml-safe/6.0'), ('6.0.3', 'pyyaml-safe/6.0'),
                                 ('7.1.0', 'pyyaml-safe/7.1')):
            with self.subTest(version=version), mock.patch.object(YAML, '__version__', version):
                self.assertIs(doctor.parser_dependency(), YAML)
                result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
                self.assertEqual(result['parser_profile'], profile)

    def test_timeout_is_never_relabeled(self):
        self.assertTrue(issubclass(doctor.InspectionTimeout, BaseException))
        self.assertFalse(issubclass(doctor.InspectionTimeout, Exception))
        with self.assertRaises(doctor.InspectionTimeout):
            doctor.alarm_expired(None, None)
        self.profile(BASE, 'first.yaml')
        self.profile(SUPPORT, 'second.yaml')
        self.profile(BASE.replace(b'source_directories: []', b'source_directories: [/sources/x]'),
                     'third.yaml')
        original_read, original_open = doctor.SafeFS.read, doctor.SafeFS.open

        def expire_on_read(fs, path):
            if path.endswith('second.yaml'):
                raise doctor.InspectionTimeout()
            return original_read(fs, path)

        def expire_on_source_probe(fs, path, directory=False):
            if '/sources/' in path:
                raise doctor.InspectionTimeout()
            return original_open(fs, path, directory)

        for name, patch in (('read', expire_on_read), ('open', expire_on_source_probe)):
            with self.subTest(during=name), mock.patch.object(doctor.SafeFS, name, patch):
                result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
            rendered = json.dumps(result)
            self.assertTrue(result['truncated'])
            self.assertFalse(result['complete'])
            self.assertIn('inspection_incomplete', self.codes(result))
            self.assertNotIn('filesystem_unsupported', rendered)
            self.assertNotIn('source_path_unknown', rendered)
            self.assertLess(len(result['profiles']), 3)
            self.assertTrue(all(p['proposal'] is None for p in result['profiles']))
            self.assertEqual(result['outcome'], 'partial' if result['profiles'] else 'failed')
        with mock.patch.object(doctor, 'discover', side_effect=doctor.InspectionTimeout):
            result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertEqual((result['outcome'], result['truncated'], result['profiles']),
                         ('failed', True, []))

    def test_main_reports_timeout_outside_profile_loop(self):
        stdout = io.StringIO()
        with mock.patch.object(doctor.resource, 'setrlimit'), \
                mock.patch.object(doctor.signal, 'signal'), \
                mock.patch.object(doctor.signal, 'alarm'), \
                mock.patch.object(doctor, 'inspect', side_effect=doctor.InspectionTimeout), \
                mock.patch.object(sys, 'stdout', stdout):
            doctor.main()
        result = json.loads(stdout.getvalue())
        self.assertEqual((result['outcome'], result['truncated']), ('failed', True))
        self.assertEqual(self.codes(result), {'inspection_incomplete'})

    def test_non_ascii_and_undecodable_mount_points(self):
        table = (b'1 0 8:1 / / rw - ext4 /dev/root rw\n'
                 b'2 1 8:2 / /srv/caf\xc3\xa9 rw - ext4 /dev/sdb rw\n'
                 b'3 1 8:3 / /srv/raw\xff rw - nfs host:/x rw\n'
                 b'4 1 8:4 / /srv/with\\040space rw - xfs /dev/sdc rw\n')
        with mock.patch('builtins.open', mock.mock_open(read_data=table)):
            rows = doctor.mount_table()
        self.assertIn(('/srv/caf\u00e9', 'ext4'), rows)
        self.assertIn(('/srv/with space', 'xfs'), rows)
        fs = doctor.SafeFS(rows)
        self.assertTrue(fs.local('/srv/caf\u00e9/config'))
        self.assertFalse(fs.local(os.fsdecode(b'/srv/raw\xff/config')))

    def test_runtime_read_race_and_inaccessible_budget_fail_closed(self):
        self.profile(SUPPORT)
        # Interrupted/short read cannot become an eligible proposal.
        with mock.patch.object(os, 'read', return_value=b'short'):
            with self.assertRaises(doctor.Refusal):
                self.fs.read(str(self.root / 'etc/borgmatic.d/fixture.yaml'))
        with mock.patch.object(doctor.SafeFS, 'open', side_effect=PermissionError):
            paths, codes = doctor.discover(self.fs, str(self.root))
        self.assertEqual(paths, [])
        self.assertIn('filesystem_unsupported', codes)

    def test_schema_conformance(self):
        try:
            import jsonschema
        except ImportError:
            self.skipTest('optional existing jsonschema tool unavailable; do not install')
        schema = json.loads((ROOT / 'libs/backup_config_doctor/schema.json').read_text())
        jsonschema.Draft202012Validator.check_schema(schema)
        validator = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
        for raw in (BASE, SUPPORT, b'CANARY_SECRET: [', BASE + b'include: secret'):
            self.profile(raw)
            result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
            validator.validate(result)
            for profile in result['profiles']:
                for entry in profile['findings']:
                    self.assertEqual(entry['message'], doctor.MESSAGES[entry['code']])

    def test_cli_never_invokes_fake_providers_hooks_or_env(self):
        binary_dir = self.root / 'bin'
        binary_dir.mkdir()
        sentinel = self.root / 'SIDE_EFFECT'
        # A fake python3 first on PATH proves the entry point pins PATH; the
        # other fakes would only be reachable through an unpinned PATH.
        for name in ('python3', 'borg', 'borgmatic', 'ssh', 'curl', 'wget', 'yq', 'script_init', 'hook-canary'):
            binary = binary_dir / name
            binary.write_text(f'#!/bin/sh\nprintf called > "{sentinel}"\nexit 91\n')
            binary.chmod(0o700)
        # PYTHONPATH/PYTHONHOME are unset by the entry point and ignored by -I.
        module_dir = self.root / 'pymodules'
        module_dir.mkdir()
        for module in ('yaml.py', 'json.py', 'sitecustomize.py'):
            (module_dir / module).write_text(f'open({str(sentinel)!r}, "w").write("imported")\n')
        # -I also disables the user site-packages that HOME would select.
        user_site = (self.root / 'home/.local/lib' / f'python{sys.version_info[0]}.{sys.version_info[1]}'
                     / 'site-packages')
        user_site.mkdir(parents=True)
        (user_site / 'yaml.py').write_text(f'open({str(sentinel)!r}, "w").write("user site")\n')
        # An executable-looking env file is never sourced or evaluated.
        (self.root / '.env').write_text(f'touch "{sentinel}"\n')
        self.profile(SUPPORT + b'before_backup: [hook-canary]\n')
        completed = subprocess.run(
            ['bash', str(ROOT / 'backup_config_doctor.sh'), '--test-mode', 'inspect', str(self.root)],
            env={**os.environ, 'PATH': str(binary_dir) + ':' + os.environ['PATH'],
                 'PYTHONPATH': str(module_dir), 'PYTHONHOME': str(self.root / 'missing-home'),
                 'PYTHONSTARTUP': str(module_dir / 'yaml.py'), 'HOME': str(self.root / 'home')},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(completed.stderr, b'')
        self.assertFalse(sentinel.exists())
        result = json.loads(completed.stdout)
        # Hooks are never executed; their programs stay a declared limitation.
        self.assertIn('hook_programs_not_inspected', result['limitations'])
        self.assertIsNotNone(result['profiles'][0]['proposal'])

    def test_zero_writes_network_commands_environment_and_confidentiality(self):
        self.profile(SUPPORT)
        before = {str(p): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        events = []

        def guard(event, args):
            if event == 'open':
                _, mode, flags = args
                if (isinstance(flags, int) and flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC)):
                    events.append('write')
                    raise AssertionError('doctor attempted write')
            if event.startswith(('subprocess.', 'socket.', 'os.system', 'os.exec', 'os.spawn',
                                 'os.posix_spawn', 'os.fork', 'os.forkpty', 'os.kill',
                                 'os.remove', 'os.rename', 'os.mkdir', 'os.rmdir', 'os.chmod',
                                 'os.chown', 'os.chflags', 'os.truncate', 'os.utime',
                                 'os.link', 'os.symlink', 'shutil.', 'ctypes.', 'urllib.')):
                events.append(event)
                raise AssertionError('doctor attempted side effect')

        # Audit hooks cannot be removed; arm only during the inspected call.
        armed = [True]
        sys.addaudithook(lambda event, args: guard(event, args) if armed[0] else None)
        stdout = io.StringIO()
        try:
            with mock.patch.dict(os.environ, {'CANARY_DATABASE': 'CANARY_VALUE'}):
                result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
                # main() too, with process limits/alarm stubbed for the test runner.
                with mock.patch.object(doctor.resource, 'setrlimit'), \
                        mock.patch.object(doctor.signal, 'signal'), \
                        mock.patch.object(doctor.signal, 'alarm'), \
                        mock.patch.object(sys, 'argv', ['doctor', '--test-mode', 'inspect', str(self.root)]), \
                        mock.patch.object(sys, 'stdout', stdout):
                    doctor.main()
        finally:
            armed[0] = False
        self.assertIsNotNone(json.loads(stdout.getvalue())['profiles'][0]['proposal'])
        self.assertEqual(events, [])
        self.assertIsNotNone(result['profiles'][0]['proposal'])
        self.assertEqual(before, {str(p): p.read_bytes() for p in self.root.rglob('*') if p.is_file()})
        rendered = json.dumps(result)
        for secret in ('CANARY', str(self.root), 'fixture-repository', 'support'):
            # 'support' is part of fixed protocol strings; inspect raw input
            # values through an exact JSON string instead.
            if secret == 'support':
                self.assertNotIn('"support"', rendered)
            else:
                self.assertNotIn(secret, rendered)

    def test_cli_contract_and_secret_projection(self):
        self.profile(SUPPORT)
        result = self.cli('--test-mode', 'inspect', str(self.root))
        self.assertEqual(result['protocol_version'], 'backup-config-doctor/1')
        self.assertIsNotNone(result['profiles'][0]['proposal'])
        for args in (('apply',), ('inspect', '--config-root', str(self.root)),
                     ('--test-mode', 'inspect', str(self.root / 'missing'))):
            rejected = self.cli(*args)
            self.assertIn(rejected['outcome'], ('unsupported', 'failed'))
        self.profile(b'CANARY_SECRET: [')
        result = self.cli('--test-mode', 'inspect', str(self.root))
        self.assertNotIn('CANARY', json.dumps(result))

    def test_cli_relative_invocation_resolves_script_directory(self):
        self.profile(SUPPORT)
        completed = subprocess.run(['bash', 'backup_config_doctor.sh', '--test-mode', 'inspect', str(self.root)],
                                   cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        self.assertEqual((completed.returncode, completed.stderr), (0, b''))
        self.assertIsNotNone(json.loads(completed.stdout)['profiles'][0]['proposal'])

    def test_handles_are_invocation_local_not_content_derived(self):
        one, two = self.analyze(SUPPORT), self.analyze(SUPPORT)
        self.assertNotEqual(one['profile_id'], two['profile_id'])
        self.assertNotEqual(one['proposal']['proposal_id'], two['proposal']['proposal_id'])

    def test_brolit_templates_are_analyzable(self):
        for name in ('default', 'docker'):
            with self.subTest(template=name):
                result = self.analyze(template(name), test=False)
                codes = self.codes(result)
                self.assertNotIn('unsupported_profile', codes)
                self.assertNotIn('hook_intent_unknown', codes)
                self.assertEqual(codes, {'source_path_unknown', 'manual_review_required'})
                self.assertEqual(result['configuration_state'], 'ambiguous')
        for name in ('mysql', 'postgres'):
            with self.subTest(template=name):
                result = self.analyze(template(name, b'fixture_db'), test=False)
                codes = self.codes(result)
                self.assertNotIn('unsupported_profile', codes)
                self.assertIn('database_mapping_ambiguous', codes)
                self.assertIsNone(result['proposal'])
                # Without the generator's constant the {database} reference is unresolved.
                self.assertIn('unresolved_constant', self.codes(self.analyze(template(name), test=False)))

    def test_support_like_legacy_profiles(self):
        for name in ('default', 'docker'):
            raw = template(name, b'"${CANARY_DATABASE}" # legacy, unreferenced')
            with self.subTest(template=name):
                result = self.analyze(raw, test=False)
                codes = self.codes(result)
                self.assertIn('unused_constant_candidate', codes)
                self.assertIn('source_path_unknown', codes)
                self.assertIsNotNone(result['proposal'])
                text, root, _ = doctor.parse(raw, YAML)
                self.assertEqual(doctor.minimal_deletion(text, root, YAML), raw.replace(
                    b'    database: "${CANARY_DATABASE}" # legacy, unreferenced\n', b''))
        self.profile(template('default', b'"${CANARY_DATABASE}"'), 'support.example.com.yml')
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        profile = result['profiles'][0]
        self.assertEqual((profile['file'], profile['location']), ('support.example.com.yml', 'etc_borgmatic_d'))
        self.assertIsNotNone(profile['proposal'])
        self.assertEqual(result['outcome'], 'partial')
        self.assertNotIn('CANARY', json.dumps(result))

    def test_hook_intent_guard(self):
        for hook in (b'mysqldump --databases site', b'cat /etc/borgmatic.d/site.yml',
                     b'grep x /root/.config/borgmatic/config.yaml', b'borgmatic config validate',
                     b'borgmatic --config /x list', b'borgmatic -c /x list', b'Echo DATABASE', b'  '):
            with self.subTest(hook=hook):
                result = self.analyze(SUPPORT + b'before_backup: ["' + hook + b'"]\n')
                self.assertIn('hook_intent_unknown', self.codes(result))
                self.assertEqual(result['configuration_state'], 'ambiguous')
                self.assertFalse(result['complete'])
                self.assertIsNone(result['proposal'])
        for hook in (b'echo start', b'send_notification \\"Borgmatic\\" \\"Error\\" \\"alert\\"',
                     b'docker compose -f /var/www/{project}/docker-compose.yml logs'):
            with self.subTest(hook=hook):
                result = self.analyze(SUPPORT + b'on_error: ["' + hook + b'"]\n')
                self.assertNotIn('hook_intent_unknown', self.codes(result))
                self.assertIsNotNone(result['proposal'])

    def test_borg_placeholders_only_in_archive_fields(self):
        for extra in (b'archive_name_format: "{project}-{now:%Y-%m-%dT%H:%M:%S}"\n',
                      b'archive_name_format: "{hostname}-{utcnow}-{reverse-fqdn}"\n',
                      b'match_archives: "sh:{project}-*"\n'):
            with self.subTest(extra=extra):
                result = self.analyze(SUPPORT + extra)
                self.assertNotIn('unsupported_profile', self.codes(result))
                self.assertIsNotNone(result['proposal'])
        for extra in (b'source_directories: ["/x/{now:%Y}"]\n',
                      b'archive_name_format: "{now:%Y{database}}"\n',
                      b'archive_name_format: "{now:$HOME}"\n',
                      b'archive_name_format: "{bogus:%Y}"\n'):
            with self.subTest(extra=extra):
                raw = SUPPORT.replace(b'source_directories: []\n', b'') + extra
                result = self.analyze(raw)
                self.assertTrue(self.codes(result) & {'unsupported_profile', 'environment_dependency_unavailable'})
                self.assertIsNone(result['proposal'])
        # A bare {name} that is a constant stays a constant reference.
        shadow = SUPPORT.replace(b'  project: support\n', b'  project: support\n  hostname: srv\n')
        self.assertIsNotNone(self.analyze(shadow + b'archive_name_format: "{hostname}"\n')['proposal'])
        self.assertIsNone(self.analyze(SUPPORT + b'archive_name_format: "{database}"\n')['proposal'])

    def test_checks_shapes(self):
        valid = BASE + (b'checks:\n  - name: spot\n    frequency: always\n    max_duration: 600\n'
                        b'    only_run_on: [Sunday]\n  - name: archives\ncheck_last: 0\n')
        self.assertEqual(self.analyze(valid)['configuration_state'], 'valid_for_supported_static_checks')
        for extra in (b'checks: [{name: bogus}]\n', b'checks: [{name: archives, extra: 1}]\n',
                      b'checks: archives\n', b'checks: [{name: [archives]}]\n', b'checks: [{}]\n',
                      b'checks: [{name: data, max_duration: soon}]\n',
                      b'checks: [{name: data, only_run_on: Sunday}]\n',
                      b'check_last: -1\n', b'check_last: true\n'):
            with self.subTest(extra=extra):
                self.assertIn('unsupported_profile', self.codes(self.analyze(BASE + extra)))

    def test_profiles_identified_by_file_and_location(self):
        self.profile(SUPPORT, 'support.example.com.yml')
        self.profile(BASE + b'constants: {hostname: srv}\nmysql_databases: [{name: all}]\n', 'server-db.yaml')
        (self.root / 'etc/borgmatic').mkdir()
        (self.root / 'etc/borgmatic/config.yaml').write_bytes(BASE)
        (self.root / 'root/.config/borgmatic.d').mkdir(parents=True)
        (self.root / 'root/.config/borgmatic').mkdir()
        (self.root / 'root/.config/borgmatic/config.yaml').write_bytes(BASE)
        (self.root / 'root/.config/borgmatic.d/root-profile.yml').write_bytes(BASE)
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        seen = {(p['location'], p['file']) for p in result['profiles']}
        self.assertEqual(seen, {('etc_borgmatic', 'config.yaml'), ('etc_borgmatic_d', 'server-db.yaml'),
                                ('etc_borgmatic_d', 'support.example.com.yml'),
                                ('root_config_borgmatic', 'config.yaml'),
                                ('root_config_borgmatic_d', 'root-profile.yml')})
        db = next(p for p in result['profiles'] if p['file'] == 'server-db.yaml')
        self.assertIn('database_mapping_ambiguous', self.codes(db))
        self.assertNotIn(str(self.root), json.dumps(result))
        # Root's default locations are inventoried with the same shape rules.
        (self.root / 'root/.config/borgmatic.d/nested').mkdir()
        result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertIn('discovery_unsupported', self.codes(result))
        self.assertTrue(all(p['proposal'] is None for p in result['profiles']))
        for limitation in ('borgmatic_semantics_uncertified', 'explicit_config_paths_not_inspected'):
            self.assertIn(limitation, result['limitations'])

    def test_unprojectable_file_name_is_counted_not_analyzed(self):
        self.profile(SUPPORT, 'caf\u00e9 CANARY.yml')
        with mock.patch.object(doctor, 'analyze', side_effect=AssertionError('must not analyze')):
            result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        profile = result['profiles'][0]
        self.assertIsNone(profile['file'])
        self.assertIn('discovery_unsupported', self.codes(profile))
        self.assertIn('discovery_unsupported', self.codes(result))
        self.assertNotIn('CANARY', json.dumps(result))

    def test_test_mode_refuses_root_and_relative_roots(self):
        self.profile(SUPPORT)
        with mock.patch.object(doctor.os, 'geteuid', return_value=0), \
                mock.patch.object(doctor.os, 'open', side_effect=AssertionError('no filesystem access')):
            with self.assertRaises(doctor.Refusal) as refused:
                doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertEqual(refused.exception.code, 'invalid_invocation')
        with self.assertRaises(doctor.Refusal):
            doctor.inspect(['--test-mode', 'inspect', os.path.relpath(self.root)])

    def test_shared_constants_match_observer_parser(self):
        path = ROOT / 'libs/backup_observation/borgmatic_profile.py'
        observer_spec = importlib.util.spec_from_file_location('borgmatic_profile', path)
        observer = importlib.util.module_from_spec(observer_spec)
        observer_spec.loader.exec_module(observer)
        # Local copies keep the doctor independent of the pinned observer wire
        # contract; the doctor's TOKEN grammar is intentionally stricter.
        self.assertEqual(doctor.MAX_BYTES, observer.MAX_FILE_BYTES)
        self.assertEqual(doctor.RETENTION_KEYS, observer.RETENTION_KEYS)
        self.assertEqual(doctor.HOOK_KEYS, observer.HOOK_KEYS)

    def test_open_identity_mismatch_and_no_fd_leak(self):
        path = self.profile()
        real = os.stat(path)
        swapped = os.stat_result((real.st_mode, real.st_ino + 1) + tuple(real)[2:10])
        original_fstat = os.fstat
        before = len(os.listdir('/proc/self/fd'))

        def fstat(fd):
            meta = original_fstat(fd)
            return swapped if (meta.st_dev, meta.st_ino) == (real.st_dev, real.st_ino) else meta

        with mock.patch.object(doctor.os, 'fstat', fstat):
            with self.assertRaises(doctor.Refusal):
                self.fs.open(str(path))
        self.assertEqual(len(os.listdir('/proc/self/fd')), before)

    def test_timeout_during_descriptor_swap_is_not_relabeled(self):
        path = self.profile()
        original_close = os.close
        closed = []

        def close(fd):
            closed.append(fd)
            original_close(fd)
            if len(closed) == 1:
                raise doctor.InspectionTimeout()

        with mock.patch.object(doctor.os, 'close', close):
            with self.assertRaises(doctor.InspectionTimeout):
                self.fs.open(str(path))
        self.assertEqual(len(closed), len(set(closed)))

    def test_unparsed_sibling_suppresses_every_proposal(self):
        for sibling in (BASE + b'compression: !include /etc/borgmatic/config.yaml\n',
                        b'<<: !include /etc/borgmatic/config.yaml\nCANARY: [', BASE + b'keep_daily: 1\nkeep_daily: 2\n'):
            with self.subTest(sibling=sibling[-40:]):
                self.profile(SUPPORT, 'a.yml')
                self.profile(sibling, 'b.yml')
                result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
                support = next(p for p in result['profiles'] if p['file'] == 'a.yml')
                self.assertIsNone(support['proposal'])
                self.assertIn('manual_review_required', self.codes(support))
                self.assertIn('discovery_unsupported', self.codes(result))

    def test_hook_guard_sees_constants_and_command_word(self):
        reader = SUPPORT.replace(b'  project: support\n', b'  project: support\n  reader: "cat /etc/borgmatic.d/x.yml"\n')
        inert = SUPPORT.replace(b'  project: support\n', b'  project: support\n  reader: "echo hi"\n')
        named = SUPPORT.replace(b'  project: support\n', b'  project: support\n  database_name: site\n')
        for raw, hook in ((reader, b'{reader}'), (reader, b'sh -c {reader}'),
                          (SUPPORT, b'cd /etc && cat borgmatic/config.yaml'),
                          (SUPPORT, b'cat /srv/app/config.yml'),
                          # A constant *name* must not hide intent from the raw-body check.
                          (named, b'mysqldump {database_name}')):
            with self.subTest(hook=hook):
                result = self.analyze(raw + b'before_backup: ["' + hook + b'"]\n')
                self.assertIn('hook_intent_unknown', self.codes(result))
                self.assertIsNone(result['proposal'])
        # Environment indirection is blocked by the environment-location rule.
        result = self.analyze(SUPPORT + b'before_backup: ["$CMD run"]\n')
        self.assertIn('environment_dependency_unavailable', self.codes(result))
        self.assertIsNone(result['proposal'])
        self.assertIsNotNone(self.analyze(inert + b'before_backup: ["sh -c {reader}"]\n')['proposal'])
        # The command word itself must be literal, even when its constant is inert.
        tool = SUPPORT.replace(b'  project: support\n', b'  project: support\n  tool: external-reader\n')
        result = self.analyze(tool + b'before_backup: ["{tool} --flag"]\n')
        self.assertIn('hook_intent_unknown', self.codes(result))
        self.assertIsNone(result['proposal'])
        # Expansion is byte-bounded: a doubling chain cannot exhaust memory/time.
        chain = b''.join(b'  c%d: "{c%d}{c%d}"\n' % (i, i + 1, i + 1) for i in range(60)) + b'  c60: xxxxxxxx\n'
        bomb = SUPPORT.replace(b'  project: support\n', b'  project: support\n' + chain)
        result = self.analyze(bomb + b'before_backup: ["echo {c0}"]\n')
        self.assertIn('hook_intent_unknown', self.codes(result))
        self.assertIsNone(doctor.ConstantExpander({'c0': '{c1}{c1}', 'c1': '{c0}'}).expand('{c0}'))
        self.assertIsNone(doctor.ConstantExpander({'a': '{a}'}).expand('{a}'))
        self.assertEqual(doctor.ConstantExpander({'a': 'x{b}', 'b': 7}).expand('{a}-{z}'), 'x7-{z}')

    def test_constant_expansion_cannot_amplify_cpu(self):
        # Round-3 security probe: doubling chain, long chain and many bodies
        # previously took ~10 s in analyze(); one shared budget bounds it.
        constants = [b'  d%d: "{d%d}{d%d}"\n' % (i, i + 1, i + 1) for i in range(14)]
        constants.append(b'  d14: "{z}{z}"\n')
        # Stays under the 128-constant limit so the guard itself is exercised.
        constants += [b'  e%d: "{e%d}"\n' % (i, i + 1) for i in range(100)]
        constants.append(b'  e100: x\n')
        raw = (SUPPORT.replace(b'  project: support\n', b'  project: support\n' + b''.join(constants))
               + b'before_backup:\n' + b''.join(b'  - "echo {e1}{d0}"\n' for _ in range(25)))
        started = time.monotonic()
        result = self.analyze(raw)
        self.assertLess(time.monotonic() - started, 1.0)
        self.assertIn('hook_intent_unknown', self.codes(result))
        self.assertIsNone(result['proposal'])

    def test_memory_error_in_one_profile_keeps_the_others(self):
        self.profile(BASE, 'a.yml')
        self.profile(BASE, 'b.yml')
        original = doctor.analyze
        calls = []

        def analyze(*args, **kwargs):
            calls.append(1)
            if len(calls) == 1:
                raise MemoryError()
            return original(*args, **kwargs)

        with mock.patch.object(doctor, 'analyze', analyze):
            result = doctor.inspect(['--test-mode', 'inspect', str(self.root)])
        self.assertEqual(len(result['profiles']), 2)
        self.assertIn('inspection_incomplete', self.codes(result['profiles'][0]))
        self.assertIn('inspection_incomplete', self.codes(result))
        self.assertEqual(result['outcome'], 'partial')

    def test_main_timeout_inside_handlers_and_core_limit(self):
        original_finding = doctor.finding
        calls = []

        def finding(code):
            calls.append(code)
            if len(calls) == 1:
                raise doctor.InspectionTimeout()
            return original_finding(code)

        stdout = io.StringIO()
        with mock.patch.object(doctor.resource, 'setrlimit') as setrlimit, \
                mock.patch.object(doctor.signal, 'signal'), \
                mock.patch.object(doctor.signal, 'alarm'), \
                mock.patch.object(doctor, 'inspect', side_effect=doctor.Refusal('invalid_invocation')), \
                mock.patch.object(doctor, 'finding', finding), \
                mock.patch.object(sys, 'stdout', stdout):
            doctor.main()
        result = json.loads(stdout.getvalue())
        self.assertEqual((result['outcome'], result['truncated']), ('failed', True))
        self.assertEqual(setrlimit.call_args_list[0], mock.call(doctor.resource.RLIMIT_CORE, (0, 0)))

    def test_main_timeout_inside_main_own_handler(self):
        # An error escapes guarded(), then the alarm lands while main() maps it.
        original_finding = doctor.finding
        calls = []

        def finding(code):
            calls.append(code)
            if len(calls) == 1:
                raise doctor.InspectionTimeout()
            return original_finding(code)

        stdout = io.StringIO()
        with mock.patch.object(doctor.resource, 'setrlimit'), \
                mock.patch.object(doctor.signal, 'signal'), \
                mock.patch.object(doctor.signal, 'alarm'), \
                mock.patch.object(doctor, 'guarded', side_effect=MemoryError), \
                mock.patch.object(doctor, 'finding', finding), \
                mock.patch.object(sys, 'stdout', stdout):
            doctor.main()
        lines = stdout.getvalue().splitlines()
        self.assertEqual(len(lines), 1)
        result = json.loads(lines[0])
        self.assertEqual((result['outcome'], result['truncated']), ('failed', True))

    def test_test_mode_requires_no_effective_capabilities(self):
        self.assertEqual(doctor.effective_capabilities(), 0)
        self.profile(SUPPORT)
        for caps in (1 << 2, None):
            with self.subTest(caps=caps), \
                    mock.patch.object(doctor, 'effective_capabilities', return_value=caps), \
                    mock.patch.object(doctor.os, 'open', side_effect=AssertionError('no filesystem access')):
                with self.assertRaises(doctor.Refusal):
                    doctor.inspect(['--test-mode', 'inspect', str(self.root)])


if __name__ == '__main__':
    unittest.main(verbosity=2)
