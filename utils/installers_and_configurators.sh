#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

installers_and_configurators() {

  local installer_options
  local installer_type

  installer_options=(
    "01)" "PHP-FPM" 
    "02)" "MYSQL/MARIADB" 
    "03)" "NGINX" 
    "04)" "PHPMYADMIN" 
    "05)" "NETDATA" 
    "06)" "MONIT" 
    "07)" "COCKPIT" 
    "08)" "CERTBOT" 
    "09)" "WP-CLI" 
    "10)" "ZSH"
    )
  installer_type=$(whiptail --title "INSTALLERS AND CONFIGURATORS" --menu "\nPlease select the utility or programs you want to install or config: \n" 20 78 10 "${installer_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    log_section "Installers and Configurators"

    if [[ ${installer_type} == *"01"* ]]; then
      "${SFOLDER}/utils/installers/php_installer.sh"

    fi
    if [[ ${installer_type} == *"02"* ]]; then
      "${SFOLDER}/utils/installers/mysql_installer.sh"

    fi
    if [[ ${installer_type} == *"03"* ]]; then
      "${SFOLDER}/utils/installers/nginx_installer.sh"

    fi
    if [[ ${installer_type} == *"04"* ]]; then
      "${SFOLDER}/utils/installers/phpmyadmin_installer.sh"

    fi
    if [[ ${installer_type} == *"05"* ]]; then
      "${SFOLDER}/utils/installers/netdata_installer.sh"

    fi
    if [[ ${installer_type} == *"06"* ]]; then
      "${SFOLDER}/utils/installers/monit_installer.sh"

    fi
    if [[ ${installer_type} == *"07"* ]]; then
      "${SFOLDER}/utils/installers/cockpit_installer.sh"

    fi
    if [[ ${installer_type} == *"08"* ]]; then
      "${SFOLDER}/utils/installers/certbot_installer.sh"

    fi
    if [[ ${installer_type} == *"09"* ]]; then
      "${SFOLDER}/utils/installers/wpcli_installer.sh"

    fi
    if [[ ${installer_type} == *"10"* ]]; then

      # TODO: extract to zsh_installer.sh
      
      display --indent 2 --text "- Installing zsh and utils"

      apt-get install zsh -qq > /dev/null
      apt-get install fontconfig -qq > /dev/null

      # Download and install Oh My Zsh
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

      # Donwload and configure PowerLevel10k for Oh My Zsh
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k

      clear_last_line
      display --indent 2 --text "- Installing zsh and utils" --result "DONE" --color GREEN

      # Copying configs files
      cp "${SFOLDER}"/config/zsh/p10k.zsh ./.p10k.zsh        # Colour Reference: https://jonasjacek.github.io/colors/
      cp "${SFOLDER}"/config/zsh/zshrc ./.zshrc
      display --indent 2 --text "- Copying config files" --result "DONE" --color GREEN

      # Set ZSH_THEME
      #sed -i "s|$ZSH_THEME|powerlevel10k/powerlevel10k|g" "./.zshrc"

      display --indent 2 --text "- Configuring Oh My Zsh and P10K" --result "DONE" --color GREEN
      display --indent 4 --text "Please reboot the server to aplied changes" --tcolor YELLOW

      # Make zsh default shell
      chsh -s "$(which zsh)"

    fi

    prompt_return_or_finish
    installers_and_configurators

  fi

  menu_main_options

}

################################################################################

installers_and_configurators