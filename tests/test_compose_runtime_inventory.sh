#!/usr/bin/env bash
# Isolated Docker CLI fixtures; no daemon or actual project resources.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/../libs/local/project_helper.sh"

tmp="$(mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT
mkdir -p "${tmp}/site" "${tmp}/bin"
project="$(realpath "${tmp}/site")"
id1="$(printf '%064d' 1)"
id2="$(printf '%064d' 2)"
export FIXTURE_DIR="${tmp}" ID1="${id1}" ID2="${id2}"
cat > "${tmp}/bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  ps) [[ ! -f "${FIXTURE_DIR}/fail" ]] || exit 1; printf '%s\n%s\n' "${ID1}" "${ID2}" ;;
  inspect) case "${*: -1}" in "${ID1}") cat "${FIXTURE_DIR}/one" ;; "${ID2}") cat "${FIXTURE_DIR}/two" ;; *) exit 1 ;; esac ;;
  *) exit 1 ;;
esac
EOF
chmod +x "${tmp}/bin/docker"
export PATH="${tmp}/bin:${PATH}"
jq -n --arg id "${id1}" --arg dir "${project}" '{id:$id,project:"custom",working_dir:$dir,config_files:"custom-file.yml",mounts:[{Type:"bind",Source:($dir+"/data"),Destination:"/data"},{Type:"volume",Name:"named",Destination:"/db"},{Type:"volume",Name:("a"*64),Destination:"/anonymous"}]}' > "${tmp}/one"
jq -n --arg id "${id2}" '{id:$id,project:"other",working_dir:"/other",config_files:"other.yml",mounts:[{Type:"volume",Name:"named",Destination:"/shared"}]}' > "${tmp}/two"
inventory="$(project_compose_runtime_inventory "${project}")" || { echo 'FAIL: inventory failed'; exit 1; }
printf '%s' "${inventory}" | jq -e '.coverage == "unverified" and .exclusion == "not_proven" and (.containers | length == 1) and .containers[0].config_files == "custom-file.yml" and .containers[0].mounts[0].classification == "bind" and .containers[0].mounts[1].classification == "named_or_external" and .containers[0].mounts[1].shared == true and .containers[0].mounts[2].classification == "anonymous_candidate" and .containers[0].mounts[2].external == "unknown"' >/dev/null || { echo 'FAIL: wrong inventory'; exit 1; }
jq '.project = null' "${tmp}/one" > "${tmp}/bad"
mv "${tmp}/bad" "${tmp}/one"
if project_compose_runtime_inventory "${project}" >/dev/null; then echo 'FAIL: missing labels accepted'; exit 1; fi
jq '.project = "custom" | .mounts[0].Source = null' "${tmp}/one" > "${tmp}/bad"
mv "${tmp}/bad" "${tmp}/one"
if project_compose_runtime_inventory "${project}" >/dev/null; then echo 'FAIL: missing mount source accepted'; exit 1; fi
printf '%s\n' '{invalid' > "${tmp}/one"
if project_compose_runtime_inventory "${project}" >/dev/null; then echo 'FAIL: malformed inspection accepted'; exit 1; fi
touch "${tmp}/fail"
if project_compose_runtime_inventory "${project}" >/dev/null; then echo 'FAIL: daemon failure accepted'; exit 1; fi
echo 'PASS: runtime inventory fixtures'
