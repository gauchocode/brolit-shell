#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
# Security Helper: Perform security actions.
#
#   Refs: https://www.tecmint.com/scan-linux-for-malware-and-rootkits/
#
################################################################################

################################################################################
# Clamav Scan: Update clamav database and performs a scan.
#
# Arguments:
#  ${1} = ${directory} - directory to scan
#
# Outputs:
#  Clamav result.
################################################################################

function security_clamav_scan() {

  local directory="${1}"

  local timestamp
  local report_file
  local clamscan_result

  timestamp="$(date +%Y%m%d_%H%M%S)"

  # Stop service
  systemctl stop clamav-freshclam.service

  # Update clamav database
  freshclam

  # Log
  log_subsection "Malware Scan"

  display --indent 6 --text "- Searching for malware"
  log_event "info" "Running clamscan on ${directory}" "false"

  report_file="${BROLIT_MAIN_DIR}/reports/clamav-results-${timestamp}.log"

  # Run on specific directory with parameters:
  # -r recursive (Scan subdirectories recursively)
  # --infected (Only print infected files)
  # --no-summary (Disable summary at end of scanning)

  log_event "debug" "Running: clamscan --recursive --infected --no-summary ${directory} | grep -i 'FOUND' >>${report_file}" "false"

  clamscan_result="$(clamscan --recursive --infected --no-summary "${directory}" | grep -i 'FOUND' >>"${report_file}")"

  # Check if file is empty
  if [[ -s ${report_file} ]]; then

    # The file is not-empty.
    clamscan_result="true"

    # Log
    display --indent 6 --text "- Searching for malware" --result "DONE" --color GREEN
    display --indent 8 --text "Malware found on ${directory}" --tcolor RED
    log_event "warning" "Malware found on ${directory}. Please check result file: ${report_file}" "false"

  else

    # The file is empty.
    rm --force "${report_file}"

    clamscan_result="false"

    # Log
    display --indent 6 --text "- Searching for malware" --result "DONE" --color GREEN
    display --indent 8 --text "No malware found on ${directory}"
    log_event "info" "No malware found on ${directory}" "false"

  fi

  # Return
  echo "${clamscan_result}"

}

################################################################################
# Custom Scan: Performs a custom scan.
#
# Arguments:
#  ${1} = ${directory} - directory to scan
#
# Outputs:
#  Scan result.
################################################################################

# IMPORTANT: Refactor before use this function, too many false positives

function security_custom_scan() {

  local directory="${1}"

  log_event "info" "Running custom malware scanner" "false"
  display --indent 2 --text "- Running custom malware scanner"

  display --indent 2 --text "Result for base64_decode:"
  grep -lr --include=*.php "eval(base64_decode" "${directory}"

  display --indent 2 --text "Result for gzinflate:"
  grep -lr --include=*.php "gzinflate(" "${directory}"
  grep -lr --include=*.php "gzinflate (" "${directory}"

  display --indent 2 --text "Result for shell_exec:"
  grep -lr --include=*.php "shell_exec(" "${directory}"
  grep -lr --include=*.php "shell_exec (" "${directory}"

  display --indent 2 --text "- Custom malware scanner" --result "DONE" --color GREEN

}

################################################################################
# Process Malware Scanner: Detects cryptominers and suspicious processes
#
# Arguments:
#  none
#
# Outputs:
#  Scanner results with suspicious processes detected.
################################################################################

function security_process_scanner() {

  local timestamp
  local report_file
  local suspicious_found=false
  local temp_results

  timestamp="$(date +%Y%m%d_%H%M%S)"
  report_file="${BROLIT_MAIN_DIR}/reports/process-malware-scan-${timestamp}.log"
  temp_results=$(mktemp)

  log_subsection "Process Malware Scanner"

  display --indent 6 --text "- Scanning for malicious processes"
  log_event "info" "Starting process malware scanner" "false"

  echo "==================================" >>"${report_file}"
  echo "BROLIT PROCESS MALWARE SCAN REPORT" >>"${report_file}"
  echo "Date: $(date)" >>"${report_file}"
  echo "==================================" >>"${report_file}"
  echo "" >>"${report_file}"

  # 1. Check for processes with deleted executables (common malware technique)
  echo "[1] PROCESSES WITH DELETED EXECUTABLES:" >>"${report_file}"
  echo "----------------------------------------" >>"${report_file}"

  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      echo "${line}" >>"${report_file}"
      suspicious_found=true
    fi
  done < <(find /proc/*/exe -ls 2>/dev/null | grep -i "deleted" | awk '{print "PID:", $9, "->", $11, $12, $13}' | sed 's|/proc/||g' | sed 's|/exe||g')

  if [[ ${suspicious_found} == false ]]; then
    echo "No processes with deleted executables found." >>"${report_file}"
  fi
  echo "" >>"${report_file}"

  # 2. Check for high CPU usage processes (potential cryptominers)
  echo "[2] HIGH CPU USAGE PROCESSES (>30%):" >>"${report_file}"
  echo "-------------------------------------" >>"${report_file}"

  ps aux --sort=-%cpu | awk 'NR==1 || $3>30.0 {print $0}' >>"${report_file}"

  high_cpu_count=$(ps aux --sort=-%cpu | awk '$3>30.0 {print $0}' | wc -l)
  if [[ ${high_cpu_count} -gt 0 ]]; then
    suspicious_found=true
  fi
  echo "" >>"${report_file}"

  # 3. Check for processes with suspicious names
  echo "[3] PROCESSES WITH SUSPICIOUS NAMES:" >>"${report_file}"
  echo "-------------------------------------" >>"${report_file}"

  # Known malware/miner names - excluding legitimate system processes (kworker, systemd-resolve are legit)
  suspicious_patterns="(xmrig|minerd|ccminer|ethminer|cryptonight|coinhive|crypto-pool|stratum|linux64|linuxsys|\.\/\.|\.\-)"

  suspicious_processes=$(ps aux | grep -iE "${suspicious_patterns}" | grep -v grep | grep -v "security_helper")

  if [[ -n "${suspicious_processes}" ]]; then
    echo "${suspicious_processes}" >>"${report_file}"
    suspicious_found=true
  else
    echo "No suspicious process names found." >>"${report_file}"
  fi
  echo "" >>"${report_file}"

  # 4. Check for unusual network connections (mining pools typically use ports 3333, 4444, 5555, 7777, 8080, 14444)
  echo "[4] SUSPICIOUS NETWORK CONNECTIONS:" >>"${report_file}"
  echo "------------------------------------" >>"${report_file}"

  suspicious_ports="(3333|4444|5555|7777|8080|14444)"

  netstat -antp 2>/dev/null | grep ESTABLISHED | grep -E "${suspicious_ports}" >>"${report_file}" 2>/dev/null || \
  ss -antp 2>/dev/null | grep ESTAB | grep -E "${suspicious_ports}" >>"${report_file}" 2>/dev/null || \
  echo "No suspicious network connections found." >>"${report_file}"

  suspicious_conn_count=$(netstat -antp 2>/dev/null | grep ESTABLISHED | grep -E "${suspicious_ports}" | wc -l)
  if [[ ${suspicious_conn_count} -eq 0 ]]; then
    suspicious_conn_count=$(ss -antp 2>/dev/null | grep ESTAB | grep -E "${suspicious_ports}" | wc -l)
  fi
  if [[ ${suspicious_conn_count} -gt 0 ]]; then
    suspicious_found=true
  fi
  echo "" >>"${report_file}"

  # 5. Check for hidden directories and files in common locations
  echo "[5] HIDDEN FILES IN SUSPICIOUS LOCATIONS:" >>"${report_file}"
  echo "------------------------------------------" >>"${report_file}"

  for dir in /tmp /var/tmp /dev/shm /home/*/.config /opt; do
    if [[ -d "${dir}" ]]; then
      find "${dir}" -name ".*" -type f -executable 2>/dev/null | head -20 >>"${report_file}"
    fi
  done

  hidden_files_count=$(for dir in /tmp /var/tmp /dev/shm /home/*/.config /opt; do [[ -d "${dir}" ]] && find "${dir}" -name ".*" -type f -executable 2>/dev/null; done | wc -l)
  if [[ ${hidden_files_count} -eq 0 ]]; then
    echo "No suspicious hidden files found." >>"${report_file}"
  else
    suspicious_found=true
  fi
  echo "" >>"${report_file}"

  # 6. Check for persistence mechanisms
  echo "[6] PERSISTENCE MECHANISMS:" >>"${report_file}"
  echo "----------------------------" >>"${report_file}"

  echo "Checking crontabs..." >>"${report_file}"
  cron_suspicious=false
  for user in $(cut -d: -f1 /etc/passwd); do
    # Check crontabs but exclude known safe patterns (brolit-shell, package managers, system maintenance)
    suspicious_crons=$(crontab -u "${user}" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -iE "(curl|wget)" | grep -vE "(brolit-shell|apt|yum|dnf|certbot|letsencrypt)")
    if [[ -n "${suspicious_crons}" ]]; then
      echo "  User: ${user}" >>"${report_file}"
      echo "${suspicious_crons}" >>"${report_file}"
      cron_suspicious=true
    fi
  done
  if [[ ${cron_suspicious} == false ]]; then
    echo "No suspicious cron jobs found." >>"${report_file}"
  else
    suspicious_found=true
  fi
  echo "" >>"${report_file}"

  echo "Checking systemd services..." >>"${report_file}"
  systemctl list-units --type=service --all | grep -iE "(miner|crypto|xmr|monero)" >>"${report_file}" 2>/dev/null || echo "No suspicious systemd services found." >>"${report_file}"
  echo "" >>"${report_file}"

  # 7. Check for users with UID anomalies
  echo "[7] USER ACCOUNTS ANALYSIS:" >>"${report_file}"
  echo "----------------------------" >>"${report_file}"

  getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print "UID:", $3, "User:", $1, "Home:", $6, "Shell:", $7}' >>"${report_file}"
  echo "" >>"${report_file}"

  # Summary
  echo "==================================" >>"${report_file}"
  echo "SCAN SUMMARY" >>"${report_file}"
  echo "==================================" >>"${report_file}"

  if [[ ${suspicious_found} == true ]]; then
    echo "⚠️  WARNING: Suspicious activity detected!" >>"${report_file}"
    echo "" >>"${report_file}"
    echo "Recommended actions:" >>"${report_file}"
    echo "1. Review processes with deleted executables - likely malware" >>"${report_file}"
    echo "2. Investigate high CPU processes" >>"${report_file}"
    echo "3. Check network connections to mining pools" >>"${report_file}"
    echo "4. Kill suspicious processes: kill -9 <PID>" >>"${report_file}"
    echo "5. Remove persistence mechanisms (cron, systemd)" >>"${report_file}"
    echo "6. Check for compromised web applications" >>"${report_file}"
    echo "7. Consider full system security audit" >>"${report_file}"

    display --indent 6 --text "- Scanning for malicious processes" --result "DONE" --color GREEN
    display --indent 8 --text "⚠️  Suspicious activity detected!" --tcolor RED
    log_event "warning" "Process malware scanner found suspicious activity. Check: ${report_file}" "false"

  else
    echo "✓ No obvious malware detected in running processes." >>"${report_file}"

    display --indent 6 --text "- Scanning for malicious processes" --result "DONE" --color GREEN
    display --indent 8 --text "No suspicious processes detected"
    log_event "info" "Process malware scanner completed - no issues found" "false"
  fi

  # Clean up
  [[ -f "${temp_results}" ]] && rm -f "${temp_results}"

  # Show report location
  display --indent 8 --text "Full report: ${report_file}"
  log_event "info" "Full report saved to: ${report_file}" "false"

  # Return result
  echo "${suspicious_found}"

}

################################################################################
# Lynis audit system
#
# Arguments:
#  none
#
# Outputs:
#  Audit result.
################################################################################

function menu_security_system_audit() {

  lynis audit system

}
