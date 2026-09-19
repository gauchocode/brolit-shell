#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

cat >&2 <<'EOF'
Brolit Shell no longer updates production installations from a Git working tree.
Use the staged release installer instead:

  release/install.sh install <manifest.json> <runtime.tar.gz> [install-root]

This protects local configuration and operator changes from destructive resets.
EOF

if [[ "${1:-}" == "install" ]]; then
    exec "${ROOT_DIR}/release/install.sh" "$@"
fi

exit 2
