# Backup configuration doctor — Phase A

**Inspect/propose only. Not deployed or approved for remote execution.** No prepare,
apply or rollback operation exists. Configuration validity, a successful backup,
observed archives and a verified restore are separate claims.

## Invocation

After separate deployment/execution approval, the sole production command is:

```bash
sudo bash /root/brolit-shell/backup_config_doctor.sh inspect
```

Do not run that command as part of source validation. It reads privileged local
configuration. There is no production config-root/path argument and no commands,
YAML, patches or proposal identifiers accepted from clients. Production requires
root. Test mode is unprivileged-only and fixture-local:

```bash
fixture="$(mktemp -d)"
mkdir -p "$fixture/etc/borgmatic.d"
printf 'isolated-fixture\n' > "$fixture/.backup-config-doctor-fixture"
printf 'repositories: [/fixture-repository]\nsource_directories: []\n' > "$fixture/etc/borgmatic.d/example.yaml"
bash backup_config_doctor.sh --test-mode inspect "$fixture"
```

These setup commands write **only fixtures**; inspection itself writes nothing.
The marker prevents accidentally treating an unmarked root as a fixture; it is
not an authorization or sandbox boundary. Test mode refuses to run as root
(euid 0), with any effective capability (`CapEff` must be zero, so e.g.
`CAP_DAC_READ_SEARCH` is refused too), and with relative roots, before any
filesystem access, so it cannot be used to read root-only configurations
through a caller-supplied path. Do not
point test mode at production. The caller supplies an absolute path with no
symlink ancestors. The fixed discovery locations map below that root
(`etc/borgmatic`, `etc/borgmatic.d`, `root/.config/borgmatic`,
`root/.config/borgmatic.d`), and test-only `/sources/...` entries map below it
too, not to real `/sources`.

## Runtime and static capability

Linux Python 3.10+ (tested 3.14.8 locally, and 3.10.12 / 3.12.3 with the distro
PyYAML 5.4.1 / 6.0.1 on Ubuntu 22.04 / 24.04) and an **already installed PyYAML >= 5.4**,
the same parser profile as the observer (fleet: 5.4.1 on Ubuntu 22.04, 6.0.x on
24.04). Missing, older or malformed PyYAML versions return `parser_unavailable`;
the tool installs nothing and does not search Borgmatic/pipx environments. The
accepted major/minor is reported as `parser_profile` (`pyyaml-safe/<major.minor>`).
The entry point pins `PATH=/usr/bin:/bin`, unsets Python startup variables and
runs `python3 -I -B`, so the system interpreter runs without user site-packages,
`PYTHON*` variables or bytecode writes. `BASH_ENV` is read by bash before the
script body, so the entry point cannot neutralize it: root runs rely on sudo's
default `env_reset` (or an SSH command environment that does not export it).
No new dependencies were added.
The observer's parser remains unchanged: it cannot prove this rule's non-use.

`flat-static-v1` is a conservative static grammar, **not Borgmatic schema or
version certification**. No Borgmatic command is invoked. In particular this
delivery does not certify compatibility with Borgmatic 1.9.14 or 2.1.7; their
existing generator integration tests are separate evidence, not doctor evidence.

- Flat mapping with `constants`, `source_directories`, `repositories` (strings or
  `path`/`label` mappings), simple exclusions, compression, passcommand, archive
  naming/matching, flat retention, hooks and consistency checks (`checks` as a
  list of `name` mappings with optional `frequency`/`max_duration`/`only_run_on`,
  and a non-negative integer `check_last`). This covers every
  `config/borg/borgmatic.template-*.yml` as generated. The exact allowlist is `TOP_KEYS` in
  `libs/backup_config_doctor/doctor.py`. Shape checks are deliberately limited;
  `valid_for_supported_static_checks` is never full Borgmatic schema validity.
- Constant names are simple identifiers; values are strings/numbers. Scan every
  scalar value, including database fields and hook strings, for `{identifier}`
  references. Analyze all constant edges/cycles, including otherwise unused
  constants. Possible brace references inside environment expressions count as
  possible use (expansion order is not assumed).
- `$NAME` / `${NAME}` are environment dependencies, never resolved from process
  environment or application `.env` files. Other brace/dollar forms are
  unsupported, including defaults, escaping and command substitutions.
- Unknown top-level fields, nested legacy sections, includes, explicit tags
  (even standard tags), anchors, aliases (budget **zero**), merges, non-string
  keys, timestamps, multiple documents, duplicate keys and excess depth/events
  are rejected. Nonempty `encryption_passcommand` is unsupported.
- Hooks (`before_backup`, `after_backup`, `on_error`) must be lists of strings.
  Their bodies are scanned for references like every other value, but the
  programs they run are never inspected (`hook_programs_not_inspected`). A body
  yields `hook_intent_unknown`, which makes the profile ambiguous and blocks
  proposals, when it is empty, its command word is not literal (contains `{`,
  `}` or `$`), or the body — checked both as written and with constants
  statically expanded (each constant resolved once; all expansions of a profile
  share one 1 MiB character budget; over-budget or cyclic expansion counts as
  unknown) — mentions
  `database`, a Borgmatic configuration location (`/etc/borgmatic`,
  `.config/borgmatic`, `borgmatic/`, `borgmatic.d`), a `config.yml`/`config.yaml`
  file, or a configuration reader (`borgmatic config|validate|-c|--config`).
  Brolit's own `echo`, `docker compose … logs` and `send_notification` hooks
  pass. This is a denylist for an informational proposal; it is **not** a
  sufficient gate for any future apply step, which requires an exact allowlist.
- Borg runtime placeholders (`{now}`, `{utcnow}`, `{hostname}`, `{fqdn}`,
  `{reverse-fqdn}`, `{user}`, `{pid}`, `{uuid4}`, `{borgversion}`, `{borgmajor}`,
  `{borgminor}`, `{borgpatch}`, optionally with a `:format` that contains no
  braces or `$`) are accepted only in `archive_name_format` and `match_archives`.
  A bare `{name}` that is also a defined constant stays a constant reference,
  because Borgmatic interpolates constants first. Elsewhere, recognized runtime
  placeholder names without explicit constants are unsupported rather than
  being interpreted as proof of a malformed Borgmatic configuration.
- MySQL/MariaDB/PostgreSQL declarations always require operator review. Project
  names, proxies and `.env` existence do not prove intended database coverage.

## Borgmatic compatibility evidence (2026-10-26)

Checked against Borgmatic **1.9.14** and **2.1.7** (pip, disposable Ubuntu 24.04
containers, network disconnected after install, synthetic profiles generated
from `config/borg/borgmatic.template-default.yml`, a fake `borg` that only
logs its arguments). `config validate --show` was used for interpolation and
`--dry-run create` for runtime loading. Results were identical in both
versions unless noted:

| Doctor assumption | Result |
|---|---|
| An unused `constants.database: "${VAR}"` with `VAR` unset breaks the profile | Confirmed: runtime loading fails with "Cannot find variable … in environment" for the whole file. `config validate` does **not** resolve environment variables and accepts it. |
| Deleting that single line repairs loading | Confirmed: the doctor's prospective bytes are identical to the generated template and load normally. |
| `{now:…}` in `archive_name_format` reaches Borg untouched | Confirmed. |
| A bare `{hostname}` that is a defined constant is a constant reference | Confirmed (constants are interpolated first). |
| Constants are interpolated inside hooks | Confirmed (1.9.14 shell-quotes the substituted value). |
| A constant referencing another constant | **Differs**: 1.9.14 resolves it transitively; 2.1.7 leaves `{database}` literal. The doctor treats any such reference as possible use, which is safe for both. |
| `${VAR:-default}` | Supported by Borgmatic; the doctor reports `unsupported_profile` (conservative). |
| `<<: !include` | Supported by Borgmatic; the doctor refuses tags (conservative) and suppresses every proposal in the run. |
| Default discovery | Both load `/etc/borgmatic/config.yaml`, top-level `*.yaml`/`*.yml` in `/etc/borgmatic.d`, `/root/.config/borgmatic/config.yaml` and top-level `*.yaml`/`*.yml` in `/root/.config/borgmatic.d`; nested directories and other suffixes are ignored. The doctor inventories the same files and, conservatively, reports the ignored entries as `discovery_unsupported`. |
| Hook keys | 2.1.7 deprecates `before_backup`/`after_backup`/`on_error` in favour of `commands:`. The doctor does not accept `commands:` yet, so profiles migrated to it are `unsupported_profile` (no proposal) until a separately reviewed extension. |

This verifies the semantics the single proposal rule depends on for these two
versions; it is not full Borgmatic schema validation, so the
`borgmatic_semantics_uncertified` limitation stays in the protocol.

## Discovery and filesystem safety

Production scope is exactly `/etc/borgmatic/config.yaml`, direct `.yml` and
`.yaml` children of `/etc/borgmatic.d`, and root's default locations
`/root/.config/borgmatic/config.yaml` and direct children of
`/root/.config/borgmatic.d`. These are fixed paths: `$HOME` and
`$XDG_CONFIG_HOME` are never read. Other entries, nested directories and
alternate single-config suffixes explicitly prevent discovery completeness, and
a failure in one location does not drop the others. No recursive search or
environment/CLI-selected Borgmatic roots are claimed: Brolit invokes
`borgmatic --config <file>`, and such explicit paths are not inventoried
(`explicit_config_paths_not_inspected`). `complete` is relative to this fixed
scope and static profile, never proof that every runtime invocation has been found.

Before each ancestor access, a bounded Linux mount table snapshot must identify
only known local filesystem types (`ext2/3/4`, `xfs`, `btrfs`, `overlay`, `tmpfs`,
`zfs`, `rootfs`). Unknown/remote/autofs boundaries are refused **before** touching
their paths. Ancestors use descriptor-relative no-follow directory opens; final
files must be regular, single-link, size-bounded and unchanged across the read.
Final reads/scans use `O_NOATIME` without a permission fallback, avoiding input
access-time writes (fixture files/directories must be owned by the test user).
Symlinks, devices, FIFOs and inaccessible paths fail closed. A privileged actor
changing mounts during inspection is outside this static snapshot trust model;
this tool does not provide a mount namespace sandbox.

**Production source metadata policy is intentionally empty.** Every source path
is unknown without accessing it: no stat, realpath, glob expansion or remote /
automount traversal to establish locality. `source_path_unknown` (and, in test
mode, `source_path_missing`) keep the profile `ambiguous`/`invalid` and
incomplete, but they are independent of removing an unused constant and do not
block the proposal. Authorized fixture-local source
paths exercise present/missing/symlink/mount refusal offline. A future production
source policy requires explicit design approval, not an arbitrary path argument.

## Single proposal rule

An informational proposal can be emitted only when:

1. `constants.database` is a scalar with an environment dependency that blocks
   supported static resolution.
2. All reference analysis is supported and complete, and there are no possible
   direct/transitive uses of that constant, no other environment dependencies,
   database mapping ambiguity, `hook_intent_unknown` or unknown fields. Source
   path findings do not block (see above).
3. It is one whole single-line entry in a block constants mapping with at least
   one other entry. Deleting precisely that line preserves every other byte.
4. Re-parsing and re-inspecting the prospective bytes in memory yields exactly
   the original findings minus `environment_dependency_unavailable` and
   `unused_constant_candidate`: the deletion resolves only that constant and
   introduces nothing new. Nothing is serialized back to YAML.
5. Fixed-root discovery has no incomplete/unsupported entries, and no
   discovered profile (including a lone one) is not fully analyzable
   (`unsupported_profile`, `yaml_invalid`, `duplicate_key`): such a profile may
   include or merge another profile's constants, so it adds
   `discovery_unsupported` and suppresses every proposal in the run.
   Cross-file reference analysis is not implemented, and configurations passed
   to Borgmatic with an explicit `--config` are not inventoried, so one of them
   could include a discovered profile unseen.

Flow/multiline/sole-entry constants or any uncertain analysis produce
`manual_review_required`, not a reserialization fallback. A database constant
that is merely unused but does not block resolution is not proposed for removal.
The public operation is exactly `remove unreferenced constants.database`. It
contains no previous value, path, raw diff, document, content hash or repair token.
There are no temporary files, persisted proposals, config edits, log writes,
network calls, Borg/Borgmatic execution, environment sourcing, hooks, `eval`,
commons loading or `script_init`. The prospective document exists only in memory.

## Protocol

Schema: [`libs/backup_config_doctor/schema.json`](../libs/backup_config_doctor/schema.json),
JSON Schema draft 2020-12. A single bounded JSON object is printed to stdout;
parser/filesystem exceptions are never printed. Handled diagnostic failures also
exit zero: consume `outcome`, never treat process success as backup health.
Interpreter/startup or OS termination failures (OOM kill, `SIGXCPU` under a
lower inherited CPU limit, a broken pipe) may have no protocol result: callers
must treat empty stdout or a nonzero exit as a failed inspection. Consumers must reject unknown versions and
additional fields and must not persist raw stderr as findings.

- `protocol_version`: `backup-config-doctor/1`; `doctor_version`: `0.2.0`;
  `capability_profile`: `flat-static-v1`; `parser_profile` (null when the parser
  was not established); UTC `inspected_at`.
- `outcome`: `complete`, `partial`, `unsupported` or `failed`. `complete` means
  all scoped evidence was examined; invalidity can still be a complete result.
  Environment/source/database uncertainties make results partial. No files is
  incomplete, never healthy. `truncated` identifies count/time/output cuts (or
  inability to establish a complete scoped inventory).
- Per profile: `file` (the configuration file's basename, the stable key
  operators correlate on), `location` (`etc_borgmatic`, `etc_borgmatic_d`,
  `root_config_borgmatic`, `root_config_borgmatic_d`), a random per-invocation
  `p_...` identifier, `configuration_state`, `complete`, fixed findings, and a
  nullable proposal. Basenames must match `[A-Za-z0-9._-]{1,128}`; any other name
  is reported as `file: null` with `discovery_unsupported` and is never
  analyzed. Profiles are ordered by path. States: `valid_for_supported_static_checks`,
  `invalid`, `ambiguous`, `unsupported`, `unknown`.
- Proposal: random `i_...`, rule `unused-database-constant` version 1, fixed
  operation, `authority: informational_only`, `dry_run: memory_only_validated`.
  Handles have invocation lifetime only, cannot select a path and authorize
  nothing. The original configuration still needs review; do not repair from
  this output.
- Fixed finding codes/messages are in `MESSAGES`. `limitations` is a fixed list:
  `static_checks_only`, `borgmatic_semantics_uncertified`,
  `explicit_config_paths_not_inspected`, `hook_programs_not_inspected`,
  `no_environment_resolution`, `no_production_source_locality_policy`,
  `no_execution_or_restore_evidence`, `no_apply_authority`. Apart from the
  allowlisted basename, raw paths, source values, credentials, URLs, parser
  errors and secret-derived hashes are intentionally absent, even on failure.

Budgets: 64 profiles; 256 KiB/config; 8192 YAML events; depth 24; zero anchors /
aliases; 1 MiB mount table; 10 seconds wall time (a single alarm: profiles
already analyzed are kept, the interrupted one is dropped, the result is
`partial`/`failed` with `truncated: true` and `inspection_incomplete`, and the
timeout is never reported as a filesystem or source-path finding); CPU soft limit 12 seconds;
256 MiB address space; core dumps disabled (`RLIMIT_CORE` 0, since a root core
would hold configuration plaintext; note that when `kernel.core_pattern` pipes
to a handler such as apport or systemd-coredump the kernel does not enforce
this limit itself, and `PR_SET_DUMPABLE` is a Phase B gate); 256 KiB JSON plus
newline. A timeout that lands while an error is being mapped to a finding is
still reported as the timeout envelope, and exactly one JSON object is printed. A `MemoryError` in one profile marks that profile and the run
`inspection_incomplete` without discarding the other profiles. Lower existing process limits
are never increased. Budget exhaustion returns unsupported/incomplete/failed,
never a disk fallback or eligible repair. Hard OS termination is not guaranteed
to produce JSON.

## Exact offline validation

From the Shell repository (no global test suite, SSH or production doctor run):

```bash
bash -n backup_config_doctor.sh
bash -n tests/backup_config_doctor/test_backup_config_doctor.sh
DOCTOR_REQUIRE_PARSER=1 bash tests/backup_config_doctor/test_backup_config_doctor.sh
bash tests/test_borg_config_generation.sh
bash tests/test_borg_init_safety.sh
bash tests/test_borg_scheduled_routing.sh
bash tests/backup_observation/test_observer.sh
python3 -I -B tests/backup_observation/test_borgmatic_profile.py
```

After staging, also run `git diff --cached --check` (it checks nothing while the
files are untracked).

The Python tests generate synthetic fixtures in a default temporary directory
and skip when no supported PyYAML exists (`DOCTOR_REQUIRE_PARSER=1` turns that
into a failure, so validation cannot pass silently). They reject
secret canaries in results, instrument writes/commands/socket activity, verify
in-memory exact-byte edits and mount checks before unsafe target metadata access,
and cover syntax, duplicates, references, cycles, unknown discovery, suffixes,
symlink ancestors/files/sources, hardlinks, FIFOs, size/event/depth/count budgets,
missing dependencies and fixed CLI failures. They also cover every Brolit
template as generated, Support-like legacy profiles (default and docker), the
hook guard, placeholder scoping, `checks` shapes, file/location projection,
root default locations, the test-mode root/capability refusal, timeouts at each
stage (including inside `main()`'s handlers and between descriptor swaps),
unparsed-sibling suppression, hook guard bypass attempts (constants, non-literal
command words, relative config paths, expansion bombs), `MemoryError`
isolation, the open-time identity check without descriptor leaks, the core-dump
limit, `PATH` pinning (a fake `python3`) and Python isolation (`PYTHONPATH`,
`PYTHONHOME`, user site-packages), and parser versions. The audit hook is armed
around both `inspect()` and `main()`. Tests must run unprivileged; the wrapper
pins `PATH` so in-process and CLI tests use the same interpreter. No dependency installs or Docker
image builds are required. No mutation-capable global suite is authorized.

Read-only code/security review remains a release gate. Production deployment,
any VPS diagnostic run, broader locality/version support and Phase B repairs
require separate approval.
