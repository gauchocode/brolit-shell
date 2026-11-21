#!/usr/bin/env bash
# Verifies updater.sh against a throwaway origin repository: a clean update to a
# tag, untracked files tolerated, and every refusal path (modified tracked file,
# detached HEAD, diverged history, unknown/lightweight/mismatched tag), the
# automatic rollback on a failing syntax check, and the explicit rollback.
# No network, no root and no real brolit tree needed.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ORIGIN="${TMP}/origin"
SEED="${TMP}/seed"

# release <version> [broken]: commit a version bump on the seed repo and push.
release() {
  local version="${1}" broken="${2:-}"
  mkdir -p "${SEED}/release" "${SEED}/cron"
  printf 'BROLIT_RELEASE_VERSION="%s"\n' "${version}" >"${SEED}/release/version.env"
  # The fake runner records its arguments, and fails for CRON_FAIL_KIND.
  cat >"${SEED}/runner.sh" <<RUNNER
#!/usr/bin/env bash
echo "runner \$*" >>"\${CRON_LOG:-/dev/null}"
[[ "\$*" == *"--subtask \${CRON_FAIL_KIND:-none}"* ]] && exit 1
exit 0
# ${version}
RUNNER
  chmod +x "${SEED}/runner.sh"
  echo "echo ok" >"${SEED}/cron/backups_tasks.sh"
  [[ -n "${broken}" ]] && echo 'if then fi (' >>"${SEED}/cron/backups_tasks.sh"
  cp "${ROOT_DIR}/updater.sh" "${SEED}/updater.sh"
  git -C "${SEED}" add -A
  git -C "${SEED}" commit -q -m "bump ${version}"
  git -C "${SEED}" push -q origin HEAD:master
}

tag_release() { git -C "${SEED}" tag -a "v${1}" -m "release ${1}" && git -C "${SEED}" push -q origin "v${1}"; }

git init -q --bare "${ORIGIN}"
git init -q -b master "${SEED}"
git -C "${SEED}" remote add origin "${ORIGIN}"
release 1.0.0; tag_release 1.0.0
release 1.1.0; tag_release 1.1.0
release 1.2.0                         # no tag yet
release 1.3.0 broken; tag_release 1.3.0
git -C "${SEED}" tag v1.4.0 && git -C "${SEED}" push -q origin v1.4.0        # lightweight
release 1.5.0; git -C "${SEED}" tag -a v1.6.0 -m wrong && git -C "${SEED}" push -q origin v1.6.0  # tag says 1.6.0, file says 1.5.0

# fresh clone at 1.0.0
new_tree() {
  local dir="${TMP}/tree-${1}"
  git clone -q "${ORIGIN}" "${dir}"
  git -C "${dir}" reset -q --hard "$(git -C "${SEED}" rev-parse v1.0.0^{commit})"
  echo "${dir}"
}

result() { echo "${1}" | sed -n 's/^UPDATER_RESULT status=\([a-z_]*\) .*/\1/p' | tail -n 1; }

# 1. no arguments: usage, exit 2, nothing changes
t="$(new_tree usage)"
"${t}/updater.sh" >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "no arguments must exit 2"

# 2. clean update with untracked files present
t="$(new_tree ok)"
touch "${t}/brolit_backups_tasks.lock"
before="$(git -C "${t}" rev-parse HEAD)"
out="$("${t}/updater.sh" update v1.1.0 2>&1)"; rc=$?
[[ ${rc} -eq 0 ]] || fail "update to v1.1.0 failed (${rc}): ${out}"
[[ "$(result "${out}")" == "updated" ]] || fail "expected status updated: ${out}"
[[ "$(git -C "${t}" rev-parse HEAD)" == "$(git -C "${SEED}" rev-parse v1.1.0^{commit})" ]] || fail "tree not at v1.1.0"
grep -q "previous=${before}" "${t}/log/updater_receipt.log" || fail "receipt missing the previous commit"

# 3. already there
out="$("${t}/updater.sh" update v1.1.0 2>&1)"; rc=$?
[[ ${rc} -eq 0 && "$(result "${out}")" == "unchanged" ]] || fail "second run must be unchanged: ${out}"

# 4. explicit rollback returns to the recorded commit
out="$("${t}/updater.sh" rollback 2>&1)"; rc=$?
[[ ${rc} -eq 0 ]] || fail "rollback failed: ${out}"
[[ "$(git -C "${t}" rev-parse HEAD)" == "${before}" ]] || fail "rollback did not restore ${before}"

# 5. a modified tracked file is refused and nothing moves
t="$(new_tree dirty)"
echo "# local" >>"${t}/runner.sh"
out="$("${t}/updater.sh" update v1.1.0 2>&1)"; rc=$?
[[ ${rc} -eq 3 && "$(result "${out}")" == "refused" ]] || fail "dirty tree must be refused (rc=${rc}): ${out}"
[[ "$(git -C "${t}" rev-parse HEAD)" == "$(git -C "${SEED}" rev-parse v1.0.0^{commit})" ]] || fail "dirty refusal moved HEAD"
grep -q '# local' "${t}/runner.sh" || fail "local change was lost"

# 6. detached HEAD is refused
t="$(new_tree detached)"
git -C "${t}" checkout -q --detach
"${t}/updater.sh" update v1.1.0 >/dev/null 2>&1; [[ $? -eq 3 ]] || fail "detached HEAD must be refused"

# 7. diverged history is refused
t="$(new_tree diverged)"
echo "local" >"${t}/local.txt"; git -C "${t}" add local.txt; git -C "${t}" commit -q -m "local only"
"${t}/updater.sh" update v1.1.0 >/dev/null 2>&1; rc=$?
[[ ${rc} -eq 3 ]] || fail "diverged history must be refused (rc=${rc})"

# 8. unknown, lightweight and mismatched tags are refused
t="$(new_tree tags)"
"${t}/updater.sh" update v9.9.9 >/dev/null 2>&1; [[ $? -eq 3 ]] || fail "unknown tag must be refused"
"${t}/updater.sh" update v1.4.0 >/dev/null 2>&1; [[ $? -eq 3 ]] || fail "lightweight tag must be refused"
"${t}/updater.sh" update v1.6.0 >/dev/null 2>&1; [[ $? -eq 3 ]] || fail "tag whose version.env disagrees must be refused"
"${t}/updater.sh" update not-a-tag >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "malformed tag must be a usage error"

# 9. a failing syntax check rolls back automatically
t="$(new_tree broken)"
before="$(git -C "${t}" rev-parse HEAD)"
out="$("${t}/updater.sh" update v1.3.0 2>&1)"; rc=$?
[[ ${rc} -eq 4 && "$(result "${out}")" == "rolled_back" ]] || fail "broken release must roll back (rc=${rc}): ${out}"
[[ "$(git -C "${t}" rev-parse HEAD)" == "${before}" ]] || fail "rollback left HEAD on the broken release"

# --- install ---------------------------------------------------------------

# 11. fresh install into a missing root: clone, move to the tag, install crons
export CRON_LOG="${TMP}/cron.log"; : >"${CRON_LOG}"
root="${TMP}/fresh/brolit-shell"
out="$("${ROOT_DIR}/updater.sh" install v1.1.0 --root "${root}" --repo "${ORIGIN}" 2>&1)"; rc=$?
[[ ${rc} -eq 0 && "$(result "${out}")" == "installed" ]] || fail "fresh install failed (rc=${rc}): ${out}"
[[ "$(git -C "${root}" rev-parse HEAD)" == "$(git -C "${SEED}" rev-parse v1.1.0^{commit})" ]] || fail "fresh install is not at v1.1.0"
[[ "$(git -C "${root}" symbolic-ref --short HEAD)" == "master" ]] || fail "fresh install must stay on a branch"
grep -q 'runner --task cron-install --subtask backups' "${CRON_LOG}" || fail "backups cron not installed"
grep -q 'runner --task cron-install --subtask ui' "${CRON_LOG}" || fail "ui cron not installed"
[[ "$(wc -l <"${CRON_LOG}")" == "2" ]] || fail "only the standard kinds must be installed"

# 12. a refused install leaves no tree behind
: >"${CRON_LOG}"
root="${TMP}/refused/brolit-shell"
out="$("${ROOT_DIR}/updater.sh" install v9.9.9 --root "${root}" --repo "${ORIGIN}" 2>&1)"; rc=$?
[[ ${rc} -eq 3 ]] || fail "unknown tag at install must be refused (rc=${rc})"
[[ ! -e "${root}" ]] || fail "a refused install left a tree behind"
[[ ! -s "${CRON_LOG}" ]] || fail "a refused install touched the crons"

# 13. an unreachable repository fails cleanly
out="$("${ROOT_DIR}/updater.sh" install v1.1.0 --root "${TMP}/nowhere/brolit-shell" --repo "${TMP}/does-not-exist" 2>&1)"; rc=$?
[[ ${rc} -eq 5 && ! -e "${TMP}/nowhere/brolit-shell" ]] || fail "clone failure must exit 5 and leave nothing (rc=${rc})"

# 14. no tag: the newest release tag is used (separate origin whose newest tag is valid)
REAL_SEED="${SEED}"; SEED="${TMP}/seed2"; ORIGIN2="${TMP}/origin2"
git init -q --bare "${ORIGIN2}"; git init -q -b master "${SEED}"; git -C "${SEED}" remote add origin "${ORIGIN2}"
release 2.0.0; tag_release 2.0.0; release 2.1.0; tag_release 2.1.0; release 2.2.0   # 2.2.0 untagged
root="${TMP}/latest/brolit-shell"
out="$("${ROOT_DIR}/updater.sh" install --root "${root}" --repo "${ORIGIN2}" --no-cron 2>&1)"; rc=$?
[[ ${rc} -eq 0 ]] || fail "install without a tag failed (rc=${rc}): ${out}"
[[ "$(git -C "${root}" rev-parse HEAD)" == "$(git -C "${SEED}" rev-parse v2.1.0^{commit})" ]] || fail "install without a tag must use the newest release tag"
SEED="${REAL_SEED}"

# 15. a pristine clone of master (HEAD ahead of the tag) is repositioned to the tag
t="${TMP}/pristine"; git clone -q "${ORIGIN}" "${t}"
: >"${CRON_LOG}"
out="$("${t}/updater.sh" install v1.1.0 --no-cron 2>&1)"; rc=$?
[[ ${rc} -eq 0 ]] || fail "pristine clone was not repositioned (rc=${rc}): ${out}"
[[ "$(git -C "${t}" rev-parse HEAD)" == "$(git -C "${SEED}" rev-parse v1.1.0^{commit})" ]] || fail "pristine clone not at v1.1.0"
[[ ! -s "${CRON_LOG}" ]] || fail "--no-cron still installed crons"

# 16. a tree with a local commit ahead of the tag is not repositioned
t="${TMP}/localcommit"; git clone -q "${ORIGIN}" "${t}"
echo local >"${t}/local.txt"; git -C "${t}" add local.txt; git -C "${t}" commit -q -m "local only"
head_before="$(git -C "${t}" rev-parse HEAD)"
"${t}/updater.sh" install v1.1.0 --no-cron >/dev/null 2>&1; rc=$?
[[ ${rc} -eq 3 && "$(git -C "${t}" rev-parse HEAD)" == "${head_before}" ]] || fail "a tree with local commits must be refused and untouched (rc=${rc})"

# 17. a cron that fails is reported with exit 6 after the tree is installed
: >"${CRON_LOG}"
out="$(CRON_FAIL_KIND=ui "${ROOT_DIR}/updater.sh" install v1.1.0 --root "${TMP}/cronfail/brolit-shell" --repo "${ORIGIN}" 2>&1)"; rc=$?
[[ ${rc} -eq 6 && "$(result "${out}")" == "installed_cron_failed" ]] || fail "a failing cron must exit 6 (rc=${rc}): ${out}"
[[ -d "${TMP}/cronfail/brolit-shell/.git" ]] || fail "the tree must stay installed when only a cron failed"

# 18. custom cron kinds
: >"${CRON_LOG}"
"${ROOT_DIR}/updater.sh" install v1.1.0 --root "${TMP}/kinds/brolit-shell" --repo "${ORIGIN}" --cron-kinds "backups security" >/dev/null 2>&1 || fail "custom kinds install failed"
[[ "$(wc -l <"${CRON_LOG}")" == "2" ]] && grep -q 'subtask security' "${CRON_LOG}" || fail "custom cron kinds not honored"
"${ROOT_DIR}/updater.sh" install v1.1.0 --root "${TMP}/bad/brolit-shell" --repo "${ORIGIN}" --cron-kinds 'backups; rm -rf /' >/dev/null 2>&1; [[ $? -eq 2 ]] || fail "unsafe --cron-kinds accepted"

# 19. bootstrap: a host whose own updater.sh is the old one runs the updater of
#     the target tag instead, taken from git, against its own tree
t="$(new_tree bootstrap)"
printf '#!/usr/bin/env bash\necho legacy updater >&2\nexit 2\n' >"${t}/updater.sh"
git -C "${t}" add updater.sh; git -C "${t}" commit -q -m "legacy updater"
git -C "${t}" reset -q --hard "$(git -C "${SEED}" rev-parse v1.0.0^{commit})"
git -C "${t}" fetch -q --tags origin
git -C "${t}" show v1.1.0:updater.sh >"${TMP}/boot-updater.sh"
out="$(bash "${TMP}/boot-updater.sh" update v1.1.0 --root "${t}" 2>&1)"; rc=$?
[[ ${rc} -eq 0 && "$(git -C "${t}" rev-parse HEAD)" == "$(git -C "${SEED}" rev-parse v1.1.0^{commit})" ]] || fail "bootstrap from the tag's updater failed (rc=${rc}): ${out}"

# 21. a stale local tag that differs from the remote does not block an update of
#     another tag (a real host carried an old v3.2-RC3 that GitHub had moved)
git -C "${SEED}" tag -a v0.1.0 -m old "$(git -C "${SEED}" rev-parse v1.0.0^{commit})"; git -C "${SEED}" push -q origin v0.1.0
t="$(new_tree stale)"
git -C "${t}" tag -f v0.1.0 "$(git -C "${t}" rev-parse HEAD)" >/dev/null   # lightweight, differs from the annotated remote tag
git -C "${t}" fetch --tags origin >/dev/null 2>&1 && fail "setup: the stale tag should make a plain 'fetch --tags' fail"
out="$("${t}/updater.sh" update v1.1.0 2>&1)"; rc=$?
[[ ${rc} -eq 0 && "$(result "${out}")" == "updated" ]] || fail "a stale unrelated tag blocked the update (rc=${rc}): ${out}"
out="$("${t}/updater.sh" status --fetch 2>&1)"; rc=$?
[[ ${rc} -eq 0 ]] || fail "status --fetch must tolerate a stale tag (rc=${rc}): ${out}"

# 20. a tag moved upstream (last: it re-points v1.1.0 in the origin for good) makes the fetch fail instead of changing the release
t="$(new_tree moved)"
"${t}/updater.sh" update v1.1.0 >/dev/null 2>&1 || fail "setup update failed"
git -C "${SEED}" tag -f -a v1.1.0 -m moved "$(git -C "${SEED}" rev-parse v1.0.0^{commit})" >/dev/null
git -C "${SEED}" push -q -f origin v1.1.0
"${t}/updater.sh" rollback >/dev/null 2>&1
out="$("${t}/updater.sh" update v1.1.0 2>&1)"; rc=$?
[[ ${rc} -eq 5 ]] || fail "a re-pointed tag must fail the fetch (rc=${rc}): ${out}"

echo "updater tests passed"
