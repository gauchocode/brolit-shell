#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################

### Setup Colours
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'
ENDCOLOR='\033[0m'

startdir=""
menutitle="Config Selection Menu"

check_root () {
  if [ ${USER} != root ]; then
    echo -e ${RED}" > Error: must be root! Exiting..."${ENDCOLOR}
    exit 0
  fi
}

check_distro () {
  # Running Ubuntu?
  DISTRO=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
  if [ ! "$DISTRO" = "Ubuntu" ] ; then
    echo " > ERROR: This script only run on Ubuntu ... Exiting"
    exit 1
  else
    echo "Setting DISTRO="$DISTRO
    MIN_V=$(echo "16.04" | awk -F "." '{print $1$2}')
    DISTRO_V=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $2}' | awk -F "." '{print $1$2}')
    if [ ! "$DISTRO_V" -ge "$MIN_V" ] ; then
      echo -e ${RED}" > ERROR: Ubuntu version must  >= 16.04 ... Exiting"${ENDCOLOR}
      exit 1
    fi
  fi
}

ChooseProjectState() {
  PROJECT_STATES="prod stage test dev"
  PROJECT_STATE=$(whiptail --title "PROJECT STATE" --menu "Chose a Project State" 20 78 10 `for x in ${PROJECT_STATES}; do echo "$x [X]"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo -e ${YELLOW}"Project state selected: ${PROJECT_STATE} ..."${ENDCOLOR}

  else
    exit 1
  fi
}

FolderToRestore() {
  if [[ -z "${FOLDER_TO_RESTORE}" ]]; then
    FOLDER_TO_RESTORE=$(whiptail --title "Folder to Restore Backup" --inputbox "Please insert a folder to restore the backup files." 10 60 "/var/www" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "FOLDER_TO_RESTORE="${FOLDER_TO_RESTORE} >> $LOG
    else
      exit 0
    fi
  fi
}
Filebrowser() {
  # first parameter is Menu Title
  # second parameter is dir path to starting folder
  if [ -z $2 ] ; then
    dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "$2"
    dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ] ; then  # Check if you are at root folder
    selection=$(whiptail --title "$1" \
                          --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
                          --cancel-button Cancel \
                          --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else   # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "$1" \
                          --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
                          --cancel-button Cancel \
                          --ok-button Select ../ BACK $dir_list 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then  # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -f "$selection" ]]; then  # Check if File Selected
      if (whiptail --title "Confirm Selection" --yesno "Selection : $selection\n" 0 0 \
                   --yes-button "Confirm" \
                   --no-button "Retry"); then
        filename="$selection"
        filepath="$curdir"    # Return full filepath and filename as selection variables
      fi
    fi
  fi
}

Directorybrowser() {
  # first parameter is Menu Title
  # second parameter is dir path to starting folder

  if [ -z $2 ] ; then
    dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "$2"
    dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ] ; then  # Check if you are at root folder
    selection=$(whiptail --title "$1" \
                          --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
                          --cancel-button Cancel \
                          --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else   # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "$1" \
                          --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
                          --cancel-button Cancel \
                          --ok-button Select ../ BACK $dir_list 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then  # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -d "$selection" ]]; then  # Check if Directory Selected
      if (whiptail --title "Confirm Selection" --yesno "Selection : $selection\n" 0 0 \
                   --yes-button "Confirm" \
                   --no-button "Retry"); then
        filename="$selection"
        filepath="$curdir"    # Return full filepath and filename as selection variables

      fi
    fi
  fi
}
