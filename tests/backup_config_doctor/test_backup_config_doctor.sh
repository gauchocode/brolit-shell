#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.2.0
# Description: Isolated doctor tests only; never loads the global suite.
# Set DOCTOR_REQUIRE_PARSER=1 to fail (not skip) when no supported PyYAML exists.
################################################################################
set -eu
# Same interpreter as the entry point (which pins PATH): the CLI tests and the
# in-process tests must see the same PyYAML.
export PATH="/usr/bin:/bin"
readonly DOCTOR_TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -I -B "${DOCTOR_TEST_DIR}/test_backup_config_doctor.py"
