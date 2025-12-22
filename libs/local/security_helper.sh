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
  suspicious_patterns="(xmrig|minerd|ccminer|ethminer|cryptonight|coinhive|crypto-pool|stratum|linux64|linuxsys|kdevtmpfsi|kdevtmpfs|\.\/\.|\.\-)"

  suspicious_processes=$(ps aux | grep -iE "${suspicious_patterns}" | grep -v grep | grep -v "security_helper")

  if [[ -n "${suspicious_processes}" ]]; then
    echo "${suspicious_processes}" >>"${report_file}"
    suspicious_found=true
  else
    echo "No suspicious process names found." >>"${report_file}"
  fi
  echo "" >>"${report_file}"

  # 4. Check for unusual network connections (mining pools typically use ports 3333, 4444, 5555, 7777, 14444)
  # Note: Port 8080 excluded as it's commonly used by legitimate web apps and docker
  echo "[4] SUSPICIOUS NETWORK CONNECTIONS:" >>"${report_file}"
  echo "------------------------------------" >>"${report_file}"

  suspicious_ports="(3333|4444|5555|7777|14444)"

  suspicious_connections=$(netstat -antp 2>/dev/null | grep ESTABLISHED | grep -E ":${suspicious_ports}" | grep -v "docker-proxy" || \
  ss -antp 2>/dev/null | grep ESTAB | grep -E ":${suspicious_ports}" | grep -v "docker-proxy")

  if [[ -n "${suspicious_connections}" ]]; then
    echo "${suspicious_connections}" >>"${report_file}"
    suspicious_found=true
  else
    echo "No suspicious network connections found." >>"${report_file}"
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
    # Check crontabs but exclude known safe patterns (brolit-shell, package managers, system maintenance, monitoring)
    suspicious_crons=$(crontab -u "${user}" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -iE "(curl|wget)" | grep -vE "(brolit-shell|broo\.be|apt|yum|dnf|certbot|letsencrypt|monitoring)")
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

  # 7. Check projects directory for suspicious files (host and docker volumes)
  echo "[7] SUSPICIOUS FILES IN PROJECTS:" >>"${report_file}"
  echo "----------------------------------" >>"${report_file}"

  if [[ -n "${PROJECTS_PATH}" && -d "${PROJECTS_PATH}" ]]; then
    echo "Scanning projects in: ${PROJECTS_PATH}" >>"${report_file}"
    echo "" >>"${report_file}"

    # A) Check host files
    echo "A) HOST FILES SCAN:" >>"${report_file}"

    # Look for suspicious executables with common malware names
    suspicious_files=$(find "${PROJECTS_PATH}" -type f -executable \( -name "*linux*" -o -name "*miner*" -o -name "*xmr*" -o -name "*kdev*" \) 2>/dev/null | head -20)

    if [[ -n "${suspicious_files}" ]]; then
      echo "Suspicious executables found:" >>"${report_file}"
      echo "${suspicious_files}" >>"${report_file}"
      suspicious_found=true
    else
      echo "No suspicious executables found in host projects." >>"${report_file}"
    fi
    echo "" >>"${report_file}"

    # Look for recently modified shell scripts (potential backdoors)
    recent_shells=$(find "${PROJECTS_PATH}" -type f \( -name "*.sh" -o -name ".*.sh" \) -mtime -7 -ls 2>/dev/null | head -10)

    if [[ -n "${recent_shells}" ]]; then
      echo "Recently modified shell scripts (last 7 days):" >>"${report_file}"
      echo "${recent_shells}" >>"${report_file}"
    fi
    echo "" >>"${report_file}"

    # Check for suspicious PHP files (web shells)
    suspicious_php=$(find "${PROJECTS_PATH}" -type f -name "*.php" -exec grep -l "eval\|base64_decode\|shell_exec\|system(" {} \; 2>/dev/null | head -10)

    if [[ -n "${suspicious_php}" ]]; then
      echo "PHP files with potentially dangerous functions:" >>"${report_file}"
      echo "${suspicious_php}" >>"${report_file}"
    fi
    echo "" >>"${report_file}"

    # B) Check Docker volumes and containers
    if command -v docker &>/dev/null; then
      echo "B) DOCKER CONTAINERS SCAN:" >>"${report_file}"

      # List running containers
      running_containers=$(docker ps --format "{{.ID}}:{{.Names}}" 2>/dev/null)

      if [[ -n "${running_containers}" ]]; then
        echo "Scanning running containers..." >>"${report_file}"
        echo "" >>"${report_file}"

        while IFS=: read -r container_id container_name; do
          echo "Container: ${container_name} (${container_id})" >>"${report_file}"

          # Check for suspicious processes inside container
          suspicious_container_procs=$(docker exec "${container_id}" ps aux 2>/dev/null | grep -iE "(xmrig|minerd|ccminer|ethminer|cryptonight|kdevtmpfs)" | grep -v grep)

          if [[ -n "${suspicious_container_procs}" ]]; then
            echo "  ⚠️  Suspicious processes found:" >>"${report_file}"
            echo "${suspicious_container_procs}" >>"${report_file}"
            suspicious_found=true
          fi

          # Check for suspicious executables in container
          suspicious_container_files=$(docker exec "${container_id}" find /var/www /app /usr/local /opt -type f -executable \( -name "*linux*" -o -name "*miner*" -o -name "*kdev*" \) 2>/dev/null | head -5)

          if [[ -n "${suspicious_container_files}" ]]; then
            echo "  ⚠️  Suspicious files found:" >>"${report_file}"
            echo "${suspicious_container_files}" >>"${report_file}"
            suspicious_found=true
          fi

          # Check high CPU usage inside container
          high_cpu_container=$(docker exec "${container_id}" ps aux --sort=-%cpu 2>/dev/null | head -5 | awk '$3>50.0 {print $0}')

          if [[ -n "${high_cpu_container}" ]]; then
            echo "  ⚠️  High CPU processes (>50%):" >>"${report_file}"
            echo "${high_cpu_container}" >>"${report_file}"
            suspicious_found=true
          fi

          echo "" >>"${report_file}"
        done <<< "${running_containers}"

        # Check Docker volumes mounted from PROJECTS_PATH
        echo "Docker volumes from ${PROJECTS_PATH}:" >>"${report_file}"
        docker ps --format "{{.Names}}" | while read -r container; do
          volumes=$(docker inspect "${container}" --format='{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{end}} {{end}}' 2>/dev/null | grep -o "${PROJECTS_PATH}[^ ]*")
          if [[ -n "${volumes}" ]]; then
            echo "  ${container}: ${volumes}" >>"${report_file}"
          fi
        done
        echo "" >>"${report_file}"

      else
        echo "No running Docker containers found." >>"${report_file}"
        echo "" >>"${report_file}"
      fi
    else
      echo "B) Docker not available for container scanning." >>"${report_file}"
      echo "" >>"${report_file}"
    fi

  else
    echo "PROJECTS_PATH not configured or directory doesn't exist." >>"${report_file}"
    echo "" >>"${report_file}"
  fi

  # 8. Check for users with UID anomalies
  echo "[8] USER ACCOUNTS ANALYSIS:" >>"${report_file}"
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
    echo "2. Investigate high CPU processes (possible cryptominers)" >>"${report_file}"
    echo "3. Check network connections to mining pools" >>"${report_file}"
    echo "4. Kill suspicious processes: kill -9 <PID>" >>"${report_file}"
    echo "5. Remove persistence mechanisms (cron, systemd)" >>"${report_file}"
    echo "6. Review suspicious files found in ${PROJECTS_PATH:-projects}" >>"${report_file}"
    echo "7. Check for compromised web applications and docker containers" >>"${report_file}"
    echo "8. Search for backdoors in recently modified scripts" >>"${report_file}"
    echo "9. Consider full system security audit with lynis" >>"${report_file}"

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Scanning for malicious processes" --result "DONE" --color GREEN
    display --indent 8 --text "⚠️  Suspicious activity detected!" --tcolor RED
    log_event "warning" "Process malware scanner found suspicious activity. Check: ${report_file}" "false"

  else
    echo "✓ No obvious malware detected in running processes." >>"${report_file}"

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Scanning for malicious processes" --result "DONE" --color GREEN
    display --indent 8 --text "No suspicious processes detected"
    log_event "info" "Process malware scanner completed - no issues found" "false"
  fi

  # Clean up
  [[ -f "${temp_results}" ]] && rm -f "${temp_results}"

  # Show report location
  display --indent 8 --text "Full report: ${report_file}"
  log_event "info" "Full report saved to: ${report_file}" "false"

  # Interactive menu for next steps (only if suspicious activity found)
  if [[ ${suspicious_found} == true ]]; then
    security_scanner_action_menu "${report_file}"
  fi

  # Return result
  echo "${suspicious_found}"

}

################################################################################
# Security Scanner Action Menu: Interactive menu for handling detected threats
#
# Arguments:
#  ${1} = ${report_file} - path to the scan report
#
# Outputs:
#  Interactive menu with remediation options
################################################################################

function security_scanner_action_menu() {

  local report_file="${1}"
  local action_options
  local chosen_action

  action_options=(
    "01)" "VIEW FULL REPORT"
    "02)" "VIEW SUSPICIOUS PROCESSES"
    "03)" "KILL SUSPICIOUS PROCESSES"
    "04)" "SEARCH AND REMOVE MALWARE FILES"
    "05)" "CHECK PERSISTENCE MECHANISMS"
    "06)" "INSPECT DOCKER CONTAINERS"
    "07)" "EXIT"
  )

  while true; do
    chosen_action=$(whiptail --title "⚠️  MALWARE DETECTED - NEXT STEPS" --menu "Suspicious activity found! Choose an action:" 20 78 10 "${action_options[@]}" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
      break
    fi

    case ${chosen_action} in
      "01)"*)
        # View full report
        if [[ -f "${report_file}" ]]; then
          whiptail --title "Security Scan Report" --scrolltext --textbox "${report_file}" 40 120
        else
          whiptail --title "Error" --msgbox "Report file not found: ${report_file}" 8 60
        fi
        ;;

      "02)"*)
        # View suspicious processes
        local temp_procs
        temp_procs=$(mktemp)

        ps aux | grep -iE "(xmrig|minerd|ccminer|ethminer|cryptonight|coinhive|kdevtmpfsi|kdevtmpfs|linuxsys)" | grep -v grep | grep -v "security_helper" > "${temp_procs}"

        if [[ -s "${temp_procs}" ]]; then
          whiptail --title "Suspicious Processes" --scrolltext --textbox "${temp_procs}" 20 120
        else
          whiptail --title "Info" --msgbox "No suspicious processes currently running.\n\nThey may have been in the report but are no longer active." 10 60
        fi

        rm -f "${temp_procs}"
        ;;

      "03)"*)
        # Kill suspicious processes
        local pids_to_kill
        pids_to_kill=$(ps aux | grep -iE "(xmrig|minerd|ccminer|ethminer|cryptonight|coinhive|kdevtmpfsi|kdevtmpfs|linuxsys)" | grep -v grep | grep -v "security_helper" | awk '{print $2}')

        if [[ -n "${pids_to_kill}" ]]; then
          local pid_list
          pid_list=$(echo "${pids_to_kill}" | tr '\n' ' ')

          whiptail --title "⚠️  WARNING" --yesno "This will kill the following PIDs:\n\n${pid_list}\n\nAre you sure you want to proceed?" 15 70

          if [[ $? -eq 0 ]]; then
            log_event "warning" "User requested to kill suspicious processes: ${pid_list}" "false"

            echo "${pids_to_kill}" | while read -r pid; do
              if [[ -n "${pid}" ]]; then
                kill -9 "${pid}" 2>/dev/null
                log_event "info" "Killed process PID: ${pid}" "false"
              fi
            done

            whiptail --title "Success" --msgbox "Suspicious processes have been terminated.\n\nCheck the logs for details.\n\nIMPORTANT: Search for persistence mechanisms to prevent reinfection!" 12 70
          fi
        else
          whiptail --title "Info" --msgbox "No suspicious processes found running." 8 50
        fi
        ;;

      "04)"*)
        # Search and remove malware files
        local search_path
        search_path=$(whiptail --title "Search for Malware Files" --inputbox "Enter path to search (e.g., /tmp, /home, ${PROJECTS_PATH}):" 10 70 "/tmp" 3>&1 1>&2 2>&3)

        if [[ -n "${search_path}" && -d "${search_path}" ]]; then
          local malware_files
          malware_files=$(find "${search_path}" -type f -executable \( -name "*linux*" -o -name "*miner*" -o -name "*xmr*" -o -name "*kdev*" -o -name ".*" \) 2>/dev/null | head -20)

          if [[ -n "${malware_files}" ]]; then
            local temp_file
            temp_file=$(mktemp)
            echo "${malware_files}" > "${temp_file}"

            whiptail --title "Suspicious Files Found" --scrolltext --textbox "${temp_file}" 20 120

            whiptail --title "⚠️  WARNING" --yesno "Do you want to DELETE these files?\n\nThis action CANNOT be undone!" 10 60

            if [[ $? -eq 0 ]]; then
              echo "${malware_files}" | while read -r file; do
                if [[ -f "${file}" ]]; then
                  rm -f "${file}"
                  log_event "warning" "Removed suspicious file: ${file}" "false"
                fi
              done
              whiptail --title "Success" --msgbox "Suspicious files have been removed.\n\nCheck logs for details." 10 60
            fi

            rm -f "${temp_file}"
          else
            whiptail --title "Info" --msgbox "No suspicious files found in:\n${search_path}" 10 60
          fi
        fi
        ;;

      "05)"*)
        # Check persistence mechanisms
        local persistence_info
        persistence_info=$(mktemp)

        {
          echo "=== CRONTABS ==="
          echo ""
          for user in root $(ls /home 2>/dev/null); do
            if crontab -u "${user}" -l 2>/dev/null | grep -v "^#" | grep -v "^$" >/dev/null; then
              echo "User: ${user}"
              crontab -u "${user}" -l 2>/dev/null | grep -v "^#" | grep -v "^$"
              echo ""
            fi
          done

          echo "=== SYSTEMD SERVICES (suspicious) ==="
          echo ""
          systemctl list-units --type=service --all | grep -iE "(miner|crypto|xmr|monero)" || echo "None found"
          echo ""

          echo "=== STARTUP SCRIPTS ==="
          echo ""
          ls -la /etc/rc.local 2>/dev/null || echo "/etc/rc.local not found"
          echo ""
          ls -la /etc/init.d/ 2>/dev/null | grep -v "^total"

        } > "${persistence_info}"

        whiptail --title "Persistence Mechanisms" --scrolltext --textbox "${persistence_info}" 30 120
        rm -f "${persistence_info}"
        ;;

      "06)"*)
        # Inspect Docker containers
        if command -v docker &>/dev/null; then
          local container_list
          container_list=$(docker ps --format "{{.Names}}" 2>/dev/null)

          if [[ -n "${container_list}" ]]; then
            local container_options=()
            while read -r container; do
              container_options+=("${container}" "Inspect container")
            done <<< "${container_list}"
            container_options+=("BACK" "Return to main menu")

            local selected_container
            selected_container=$(whiptail --title "Select Container to Inspect" --menu "Choose a container:" 20 70 10 "${container_options[@]}" 3>&1 1>&2 2>&3)

            if [[ -n "${selected_container}" && "${selected_container}" != "BACK" ]]; then
              local container_action
              container_action=$(whiptail --title "Container: ${selected_container}" --menu "Choose action:" 15 70 5 \
                "1" "View running processes" \
                "2" "Check high CPU processes" \
                "3" "Search for suspicious files" \
                "4" "View container logs" \
                3>&1 1>&2 2>&3)

              case ${container_action} in
                1)
                  local temp_container_ps
                  temp_container_ps=$(mktemp)
                  docker exec "${selected_container}" ps aux 2>/dev/null > "${temp_container_ps}"
                  whiptail --title "Processes in ${selected_container}" --scrolltext --textbox "${temp_container_ps}" 20 120
                  rm -f "${temp_container_ps}"
                  ;;
                2)
                  local temp_container_cpu
                  temp_container_cpu=$(mktemp)
                  docker exec "${selected_container}" ps aux --sort=-%cpu 2>/dev/null | head -20 > "${temp_container_cpu}"
                  whiptail --title "High CPU in ${selected_container}" --scrolltext --textbox "${temp_container_cpu}" 20 120
                  rm -f "${temp_container_cpu}"
                  ;;
                3)
                  local temp_container_files
                  temp_container_files=$(mktemp)
                  docker exec "${selected_container}" find /var/www /app /usr/local -type f -executable 2>/dev/null | head -50 > "${temp_container_files}"
                  whiptail --title "Executables in ${selected_container}" --scrolltext --textbox "${temp_container_files}" 20 120
                  rm -f "${temp_container_files}"
                  ;;
                4)
                  local temp_container_logs
                  temp_container_logs=$(mktemp)
                  docker logs --tail 100 "${selected_container}" > "${temp_container_logs}" 2>&1
                  whiptail --title "Logs: ${selected_container}" --scrolltext --textbox "${temp_container_logs}" 30 120
                  rm -f "${temp_container_logs}"
                  ;;
              esac
            fi
          else
            whiptail --title "Info" --msgbox "No running Docker containers found." 8 50
          fi
        else
          whiptail --title "Error" --msgbox "Docker is not installed or not available." 8 50
        fi
        ;;

      "07)"*)
        # Exit
        break
        ;;
    esac
  done

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
