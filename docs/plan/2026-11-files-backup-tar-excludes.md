# Plan: Files backup tar excludes fix

## Status
- **Phase**: Complete
- **Last Updated**: 2026-11-11

## Overview

Every `excluded_on_tar` pattern was silently ignored by the nightly files
backup. `backup_project_files()` concatenated the patterns into a single
string with literal single quotes around each one, and `compress()`
expanded that string unquoted: word splitting does not remove quotes, so
tar received `--exclude='*recovery-live*'` with the quote characters as
part of the pattern. No path contains a literal `'`, so nothing was ever
excluded.

Impact (production): on `tukiverse-apps01` (194.163.180.194) the backup
temp dir lives on the same disk as the data, so projects with large
"excluded" directories filled the disk while the nightly backup ran:

- **2026-11-08 ~00:44 UTC**: disk full, `wap2tukitalkcom-postgres-1` died
  and Docker stopped retrying (down until 2026-11-11, started by hand).
- **2026-11-11 ~00:40 UTC**: temp archive reached 34 GB (a 29 GB
  `recovery-live/pg_data` that the config excludes), disk hit 100%,
  TukiFeedback's Postgres went into a crash/recovery loop.

The 29 GB `recovery-live/` directory was deleted on 2026-11-11 as a
stopgap. The bug affected every project on every server.

## Implementation

### `libs/commons.sh`

- `compress()` and `decompress()` now take exclusion patterns as
  **separate arguments** (`${4}...`, one `--exclude=PATTERN` each),
  collected into a local array and expanded quoted. Empty arguments are
  filtered, so existing callers passing `""` are unaffected. The unquoted
  `${exclude_parameters}` expansions (and their `SC2086` suppressions) are
  gone.
- `decompress()` zip branch builds the `unzip -x` exclusions as an array
  as well.

### `libs/local/backup_helper.sh`

- `backup_project_files()` builds `exclude_args` as an array. The old
  `string_remove_spaces` + `tr '\n' ','` + quoted-concatenation pipeline
  was replaced by a line reader that:
  - keeps interior spaces as part of the pattern (the old code destroyed
    them: `my logs*` became `mylogs*`),
  - still tolerates comma-separated lists from configs migrated from
    older versions,
  - trims only surrounding whitespace and skips empty entries.

## Hardening added in the same change

1. **Free-space guard** in `compress()`: before archiving, the input is
   estimated with `du -sb` using the same exclusion patterns (also used
   for the `pv -s` progress size, which previously overstated progress by
   counting excluded data). If the temp filesystem has less than
   `estimate × 1.2` bytes free, the backup fails with a clear error
   instead of filling the disk and taking unrelated services down. When
   `du` or `df` cannot produce a number the guard is skipped but logs a
   warning, so the bypass is visible in the run log.
2. **Pipeline result is no longer ignored**: the tar | pv | compressor
   pipeline status is checked, so a disk-full mid-archive no longer
   reports success when the compression test is disabled. The partial
   output file is deleted on pipeline failure, on compression-test
   failure, and by `backup_project_files()` when `compress()` fails.
3. **Visibility**: `compress()` logs the effective pattern count and
   patterns (`N exclusion pattern(s): ...`), and `backup_project_files()`
   logs the same for the project, so a regression of this kind is visible
   in the run log.
4. **Argument validation**: `_collect_exclude_args()` (shared by
   `compress()` and `decompress()`) accepts only complete
   `--exclude=PATTERN` arguments and drops anything else with a warning,
   so a future caller bug cannot inject arbitrary tar/du flags.

## Tests

`tests/test_backup_tar_excludes.sh` (wired into `tests_suite.sh` as menu
option 21 and into RUN ALL):

- patterns reach `compress()` as separate, unquoted arguments (the exact
  old bug fails this), including comma-separated legacy lists,
- a real tar run excludes `pg_data/`, `recovery-live/`, `*.log`,
  `node_modules/.cache`, bracket patterns (`data[0-9]`) and
  space-containing patterns (`my logs*`), while keeping normal files
  (including `keep notes.txt`); empty and invalid extra arguments are
  filtered with a warning,
- `decompress()` applies exclude arguments,
- `compress()` aborts without creating the archive when free space is
  insufficient (fake `df`),
- `compress()` deletes the partial output when the pipeline fails (failing
  compressor).

`pv`, `df` and the compressor are faked on PATH; no network, no servers.
The suite fails against the pre-fix code for every case above except the
decompress one.

## Verification after deploying

**Executed on `tukiverse-apps01` (194.163.180.194) on 2026-11-11, v3.14.12
(`b59dd760`):**

- `./runner.sh -t backup -st project -D wap2.tukitalk.com` → EXIT=0,
  `Project Backup [ DONE ]`, temp dir cleaned, disk stable at 49G free.
- Run log: `Compressing with 10 exclusion pattern(s)` and the effective
  command `tar -cf - --directory="/var/www" --exclude=*.log … --exclude=*backup-* -h "wap2.tukitalk.com"`
  — no quote characters inside the patterns (the old bug showed
  `--exclude='*.log'`).
- `pv -s` estimate is exclude-aware: 8.65 GB vs the 11 GB raw project size.
- Archive content (same tar command, member listing):
  **0** entries matching `pg_data|redis_data|recovery-live|\.log$|\.tmp$|\.cache$|\.bak$|backup-`;
  the control run without excludes shows **7,817** such entries — what the
  buggy version archived nightly.
- Final archive: 7,380 MiB, uploaded to Dropbox, retention cleanup OK.
- Side repair: `tukibot_postgres` (down since 2026-11-09 00:44 UTC —
  third disk-full window — restart count 129) started by hand and
  recovered (WAL redo, accepting connections).

Then roll the fix to every other server running brolit-shell.

### Fleet rollout (staged)

Staged rollout started on 2026-11-11. Stage 1 (same day, ahead of the
00:45 UTC nightly window) — all pulled cleanly to v3.14.12 (`26d36314`),
fix marker and `bash -n` verified on each:

| Server | Before | `/var/www` | Free |
|--------|--------|-----------:|-----:|
| arqa-web-vm | 3.14.10 | 281G | 57G |
| gaucho-docker-host04 | 3.14.10 | 67G | 77G |
| gaucho-automate01 | 3.14.10 | 65G | 96G |
| tukiverse-apps02 | 3.14.8 | 75G | 346G |
| gaucho-docker-host03 | 3.14.9 | 39G | 88G |
| gaucho-host01-vm | 3.14.9 | 19G | 132G |
| centum-ai-services01 | 3.14.10 | 27G | 132G |

### Fleet verification (nights of 2026-11-12 and 2026-11-13)

All stage-1 servers ran the nightly backup with the fix active:

- `Compressing with N exclusion pattern(s)` (N=4 or 10) present on every
  files backup; archives sized accordingly.
- **Zero `No space left on device` events fleet-wide** (vs. two outages in
  the three nights before the fix).
- arqa-web-vm: the free-space guard fired both nights exactly as designed
  (`Not enough free space ... estimated 296776749883, available 63593132032`)
  — clean abort instead of the disk-filling gamble. Note: arqa.com has no
  real files backup (277G `wp-content` vs 60G free, excludes only remove
  ~125MB); the sustainable path is Borg (already enabled there) — pending
  decision with the site owner.
- Remaining per-project failures were all `tar=1 pv=0 lbzip2=0`: GNU
  tar's "file changed as we read it" warning class on live sites, which
  the old code silently ignored. Follow-up commit `56f81fce`: tar exit 1
  is logged as a warning and the archive kept; tar ≥ 2 or pv/compressor
  failures remain fatal. Deployed to the 8 stage-1 servers.
- gaucho-docker-host04 runs its backup at 02:15 (not 00:45) — verified
  separately, working.
- gaucho-host01-vm: `exito.com.ar` jumped from 2.7G to 11.8G in one night
  — worth a data-growth check.

### Mail section bug found during verification (fixed 2026-11-13, `893f4b8f`)

The ⛔ ERROR mails of 2026-11-13 showed every section OK while the
subject said ERROR. Cause: `backup_all_projects_files()` and
`backup_additional_dirs()` each rendered the same fixed
`files-bk-${NOW}.mail` section file, so the second render (error_msg
"none") overwrote the first one's error state; the list array was also
an undeclared global shared by both functions. Now both only append to
explicit accumulators and `backup_files_mail_render()` renders once,
naming every failed site or directory; the `files`/`all` subtasks
propagate the real exit code. Tests:
`tests/test_backup_mail_sections.sh` (suite option 22). Known follow-up
from review: `backuped_config_list` still uses the old undeclared-global
pattern in `backup_all_server_configs()` (single render per run, benign
until a function runs twice in one process).

### Stage 3 notes (from the 2026-11-13 review)

- wigou: **no common ancestor with origin/master** (ancient/divergent
  clone, ~2503 commits behind, plus a staged `brolit_lite.sh` change and
  a modified borgmatic template). Cannot pull; needs capture-diffs →
  reset to origin/master → re-apply if meaningful.
- constructoradelbosque, stellacast-gpu: unreachable during the survey.

Stage 2 (after verifying stage 1's nightly runs): **completed on
2026-11-13** — the remaining
FF-updatable servers with active backup cron (docker-host01/02, dev02,
dev04, goseries-master, redcoach-* ×5, tukiverse-dev01/apps03, bmailing,
epica-apps01, ostiaapp-vm, producir-integral-csusc, spyglass, redcoach
docker01/dev02). All 17 pulled to `ad0d2611` (v3.14.13, includes the
excludes fix, the guard, tar-exit-1 tolerance and the retention-warning
fix); fix markers and `bash -n` verified on each. Stage 1's 8 servers
realigned to the same commit. Fleet FF coverage: **25/25 servers on
v3.14.13**; first post-deploy nightly verification due 2026-11-14.

Stage 3 (needs review first — servers carry local commits never pushed):
wigou (`6fecc305`), anfibia-cronos (3.14.0, `a6b4e203`), epica-apps02
(3.14.1, `4ade6763`), gaucho-apps01-ds4, stellacast-vm, VDS-DEV,
gaucho-dedicate01 (last four have no backup cron — bug dormant).

Unreachable during the survey: constructoradelbosque, stellacast-gpu.
No brolit-shell: VDS-PROD-EPICA-EXCLUSIVO, VDS-Staging.

Known pre-existing cosmetic issue observed during verification (not part
of this fix): `backup_helper.sh` around the project-database path does an
arithmetic `[[` test on a `"<file>;<size>"` string and logs
`syntax error: invalid arithmetic operator`; the backup still succeeds.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-11 | Exclusions passed as variadic args, not a string | Word splitting/globbing cannot corrupt them; quoting survives patterns with spaces and brackets |
| 2026-11-11 | Free-space guard uses uncompressed estimate × 1.2 | Conservative for incompressible data; a failed backup is cheaper than a disk-full outage |
| 2026-11-11 | Guard skips with a warning when du/df cannot evaluate | A broken du must not disable backups, but the bypass must be visible in the run log |
| 2026-11-11 | `compress()` creates the output dir before df | `df` needs an existing path; also fixes callers that forgot `mkdir -p` |
| 2026-11-11 | Only `--exclude=PATTERN` args accepted (`_collect_exclude_args`) | Closes the tar/du flag-injection surface for future callers |
| 2026-11-11 | Comma-splitting kept in `backup_project_files()` | Configs migrated from older versions may hold comma-separated lists |
| 2026-11-11 | `restore_backup_helper.sh` caller unchanged | Its single `--exclude=*.log` string arrives as one array element and expands correctly |
