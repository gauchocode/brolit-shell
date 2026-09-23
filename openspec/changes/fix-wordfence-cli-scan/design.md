## Context

Wordfence is built from a clone under runtime state by `build_wordfencecli_docker_image()`, while the interactive installer maintains a second clone under `/root/wordfence-cli`. Both builds hide Docker output. The upstream Dockerfile currently starts from the floating `python:3.11-slim` tag and installs `libpcre3`, which is unavailable when that tag resolves to Debian trixie. The scan helper captures `docker run` output but does not emit a machine-readable clean/found result; the CLI consumer also ignores the helper's nonzero status. Cron has gained a failure check, but still relies on that same result contract.

## Goals / Non-Goals

**Goals:**
- Build from one shared clone and a repository-owned Dockerfile based on `python:3.11-slim-bookworm`.
- Pin upstream source to the reproduction version `v5.0.6` and fail visibly when source preparation or image build fails.
- Return exactly `true` or `false` on stdout for completed scans; return nonzero for execution errors.
- Ensure CLI and cron report operational failures separately from clean scans and findings.
- Add isolated Bash tests with mocked external commands and document a Docker-backed integration check.

**Non-Goals:**
- Validate Wordfence licenses through its API.
- Change ClamAV or process-scanner result contracts.
- Automatically track newer Wordfence releases; changing the pinned version is an explicit maintenance action.

## Decisions

1. **Own the Dockerfile, reuse upstream source.** Build using the checked-out upstream tree as context and pass `config/docker/wordfence-cli/Dockerfile` with `docker build -f`. This keeps the image recipe stable while retaining upstream application source. An upstream Dockerfile alone is rejected because it inherits the incompatible floating base.
2. **Use a shared, versioned checkout.** Fetch/checkout tag `v5.0.6` in the runtime-state clone; use the same helper from installer, updater, and scan paths. This prevents stale `/root` clones and makes the build repeatable. A moving branch or unconditional `git pull` is rejected because it changes build inputs silently.
3. **Separate machine result from diagnostics.** Successful scans print one boolean to stdout; progress and human-readable output use stderr/display channels. Operational failures return nonzero, while clean and malware-found scans both return zero with different boolean output. This is compatible with the existing command-substitution consumers while making errors distinguishable.
4. **Treat output-report validation as part of scan success.** Require the expected CSV and parse its rows with Python's strict CSV parser before classifying a scan. This handles quoted commas, newlines, CRLF, and invalid UTF-8 correctly. A missing or malformed report is an execution error, not a clean result. Supported Ubuntu server releases provide Python 3.
5. **Isolate concurrent scans and honor configured project paths.** Bind-mount each canonical scan directory read-only at the same absolute path inside the container. Write each run to a unique temporary report and atomically move the validated report to the expected `<basename>_scan.csv` path, so scans with matching basenames do not consume each other's intermediate output.
6. **Keep the license out of process arguments.** Serialize it as the Wordfence INI `[DEFAULT]` configuration over Docker stdin; the container writes it to a mode-600 temporary file, invokes Wordfence with only the config file path, then removes the file. Do not pass the license in argv or environment.
7. **Test the shell contract without Docker.** Source the helper in a focused test and shadow external commands with mocks. Assert the license arrives on stdin and is absent from Docker argv. Keep a manual integration check for actual image build and Wordfence execution because that depends on Docker, network access, and a valid license.

## Risks / Trade-offs

- **Pinned version can become stale** → keep the tag in one named constant and document the explicit update procedure.
- **Upstream changes its package or Docker requirements** → the Docker-backed integration check will expose incompatibilities before release.
- **Existing consumers may capture diagnostic output** → test stdout exactly and route diagnostics separately before changing callers.
- **CSV format may change between Wordfence versions** → validate only the stable structural properties needed to distinguish report presence and header, and cover fixtures in unit tests.

## Migration Plan

No persistent data migration is required. Existing runtime clones can be fetched and checked out at `v5.0.6` by the shared preparation helper. Existing `wordfence-cli:latest` images may be reused only if the helper can verify their version; otherwise rebuild using the owned Dockerfile. Rollback consists of reverting the code and Dockerfile changes; no scan state format changes are introduced.

## Open Questions

None. `v5.0.6` is selected because it is the version identified in the issue reproduction.
