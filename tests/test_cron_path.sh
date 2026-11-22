#!/usr/bin/env bash
# commons.sh must make /usr/local/bin visible under cron's minimal PATH.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail=0
out="$(env -i HOME=/tmp PATH=/usr/bin:/bin bash -c '
  source "'"${here}"'/libs/commons.sh" >/dev/null 2>&1
  echo "$PATH"' 2>/dev/null | tail -1)"
for d in /usr/local/bin; do
  [[ -d "$d" ]] || continue
  case ":${out}:" in *":$d:"*) echo "ok: $d in PATH" ;; *) echo "FAIL: $d missing from PATH ($out)"; fail=1 ;; esac
done
exit "${fail}"
