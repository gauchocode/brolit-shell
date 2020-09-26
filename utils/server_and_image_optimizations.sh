#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.3
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e "${B_RED} > Error: The script can only be runned by runner.sh! Exiting ...${ENDCOLOR}"
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"
# shellcheck source=${SFOLDER}/libs/image_reduce_helper.sh
source "${SFOLDER}/libs/image_reduce_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

#TODO: better date control

check_last_optimization_date() {

  server_opt_info=~/.server_opt-info
  if [[ -e ${server_opt_info} ]]; then
    # shellcheck source=${server_opt_info}
    source "${server_opt_info}"
    echo "${last_run}"

  else
    echo "last_run=never">>"${server_opt_info}"
    echo "never"

  fi

}

update_last_optimization_date() {

  server_opt_info=~/.server_opt-info

  echo "last_run=${NOW}">>"${server_opt_info}"

}

delete_old_logs() {

  # Remove old log files from system
  log_event "info" "Deleting old system logs ..." "true"
  ${FIND} /var/log/ -mtime +7 -type f -delete

}

clean_swap() {

  # Cleanning Swap
  log_event "info" "Cleanning Swap ..." "true"
  swapoff -a && swapon -a

}

clean_ram_cache() {

  # Cleanning RAM
  log_event "info" "Cleanning RAM ..." "true"
  sync
  echo 1 >/proc/sys/vm/drop_caches

}

################################################################################

# TODO: extract this to an option
img_compress='80'
img_max_width='1920'
img_max_height='1080'

# TODO: add an option to run image_optimization with cron

# mogrify
MOGRIFY="$(which mogrify)"

# jpegoptim
JPEGOPTIM="$(which jpegoptim)"

# optipng
OPTIPNG="$(which optipng)"

server_optimizations_options="01) PHP-OPTIMIZATION 02) IMAGE-OPTIMIZATION 03) PDF-OPTIMIZATION 04) DELETE-OLD-LOGS 05) REMOVE-OLD-PACKAGES 06) CLEAN-RAM-CACHE"
chosen_server_optimizations_options=$(whiptail --title "PHP INSTALLER" --menu "Choose a PHP version to install" 20 78 10 $(for x in ${server_optimizations_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${chosen_server_optimizations_options} == *"01"* ]]; then
    # Run php_optimizations.sh
    "${SFOLDER}/utils/php_optimizations.sh"

  fi
  if [[ ${chosen_server_optimizations_options} == *"02"* ]]; then
    # Install image optimize packages
    install_image_optimize_packages

    # Ref: https://github.com/centminmod/optimise-images
    # Ref: https://stackoverflow.com/questions/6384729/only-shrink-larger-images-using-imagemagick-to-a-ratio

    # TODO: First need to run without the parameter -mtime -7

    optimize_image_size "${SITES}" "jpg" "${img_max_width}" "${img_max_height}"

    optimize_images "${SITES}" "jpg" "${img_compress}"

    optimize_images "${SITES}" "png" ""

    # Fix ownership
    change_ownership "www-data" "www-data" "${SITES}"

  fi
  if [[ ${chosen_server_optimizations_options} == *"03"* ]]; then
    # TODO: pdf optimization
    # Ref: https://github.com/or-yarok/reducepdf

    optimize_pdfs

    # Fix ownership
    change_ownership "www-data" "www-data" "${SITES}"

  fi
  if [[ ${chosen_server_optimizations_options} == *"04"* ]]; then
    # Remove old log files from system
    delete_old_logs

  fi
  if [[ ${chosen_server_optimizations_options} == *"05"* ]]; then
    # Remove old packages from system
    remove_old_packages

  fi
  if [[ ${chosen_server_optimizations_options} == *"06"* ]]; then
    # Restarting services
    log_event "info" "Restarting services ..." "true"
    service php"${PHP_V}"-fpm restart

    # Cleanning Swap
    clean_swap

    # Cleanning RAM
    clean_ram_cache

  fi

fi


