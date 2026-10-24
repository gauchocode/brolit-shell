# Borg safety integration environment

Disposable Ubuntu 24.04 integration tests using real Borg, Borgmatic and Mike
Farah yq v4 (not Ubuntu's unrelated Python yq package). No SSH service, ports,
privileged containers, Docker socket, credentials or production repositories.
Dependencies are installed in the test image only; no host installation occurs.

```bash
docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml build
docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml run --rm --no-deps borg-safety
```

The repository is mounted read-only. Runtime networking is disabled; configurations,
security metadata, repositories and restores live in container tmpfs and disappear
when the container exits. The image build needs package/release download access.
The tmpfs allows executable fixture scripts required by the offline regression
suites; all capabilities remain dropped and runtime networking stays disabled.
The tests print installed versions; Borg comes from Ubuntu's security-updated
package repository, while Borgmatic and yq versions are pinned in the Dockerfile.

To test another Borgmatic release, set `BORGMATIC_VERSION` when building and
running. Images have distinct version tags; rebuild after changing a version's
Dockerfile or build arguments. For example:

```bash
BORGMATIC_VERSION=1.9.14 docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml build
BORGMATIC_VERSION=1.9.14 docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml run --rm --no-deps borg-safety
```

The suite exercises real-template generation, invalid database rejection,
preservation, missing-only initialization, multiple local repositories,
configuration failure classification, blocked relocation, and a local
create/extract round trip. It also runs the six offline Bash regression suites
and the observer's template-parser regressions inside the isolated container.
External-provider SSH behavior, production database consistency and repository
relocation approval remain outside this environment's coverage.

## Release packaging regression

The image includes Git and OpenSSH client tools for the isolated release tests
(there is no SSH server). The checkout remains read-only; any signing keys and
installation roots are disposable test fixtures:

```bash
docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml run --rm --no-deps --user "$(id -u):$(id -g)" borg-safety bash -c 'mkdir -p "$HOME"; git config --global --add safe.directory /workspace; bash tests/release/test_release.sh'
```

The regression script explicitly permits a dirty build for local tests only.
Publishable bundles must instead be built from a clean committed checkout.
Run packaging as the checkout owner: without capabilities, container root cannot
read owner-only checkout directories or preserve another owner's file metadata.
The release tests use their existing non-root test-install mode; do not grant
additional capabilities to bypass these protections.
