#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.2.0
# Description: Definition-only backup configuration inspection; no initialization.
################################################################################
set -eu
# The doctor boundary does not inherit executable search paths or Python
# startup variables from the caller (same policy as backup_observer.sh).
# BASH_ENV is read by bash before this line runs, so unsetting it here only
# protects child processes: root runs rely on sudo's env_reset (its default)
# or the SSH command environment not exporting BASH_ENV.
unset BASH_ENV ENV CDPATH PYTHONPATH PYTHONHOME 2>/dev/null || true
export PATH="/usr/bin:/bin"
# Absolute, symlink-resolved script directory: never resolved against the
# caller's working directory (CDPATH is already unset above).
DOCTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly DOCTOR_DIR
# Isolated Python ignores PYTHONPATH/user site and never writes bytecode. No libs
# are sourced and no production config root can be supplied.
exec python3 -I -B "${DOCTOR_DIR}/libs/backup_config_doctor/doctor.py" "$@"
