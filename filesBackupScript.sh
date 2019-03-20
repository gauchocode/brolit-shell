#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.9
#############################################################################

### VARS ###
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""

### Starting Message ###
echo -e "\e[42m > Starting file backup script...\e[0m" >> $LOG

### TAR Webserver Config Files ###
if [ -n "$WSERVER" ]; then
  if $TAR -jcvpf $BAKWP/$NOW/webserver-config-files-$NOW.tar.bz2 $WSERVER
  then
      echo " > Config Files Backup created..." >> $LOG
      echo " > Uploading TAR to Dropbox ..." >> $LOG
      $SFOLDER/dropbox_uploader.sh upload $BAKWP/"$NOW"/webserver-config-files-"$NOW".tar.bz2 $DROPBOX_FOLDER
      echo " > Trying to delete old backup from Dropbox ..." >> $LOG
      $SFOLDER/dropbox_uploader.sh remove /webserver-config-files-"$ONEWEEKAGO".tar.bz2
  else
      echo " > ERROR - No such directory or file" >> $LOG
      ERROR=true
      ERROR_TYPE="TAR ERROR: No such directory or file $BAKWP/$NOW/webserver-config-files-$NOW.tar.bz2"
  fi
fi

### TAR Sites Folders ###
if [ "$ONE_FILE_BK" = true ] ; then
  if [ -n "$SITES" ]; then
    if $TAR --exclude '.git' --exclude '*.log' -jcvpf $BAKWP/"$NOW"/backup-files_"$NOW".tar.bz2 $SITES; then
        BK_SIZE=$(ls -lah $BAKWP/"$NOW"/backup-files_"$NOW".tar.bz2 | awk '{ print $5}')
        echo " > Backup created, final size: $BK_SIZE ..." >> $LOG
        echo " > Uploading TAR to Dropbox ..." >> $LOG
        $SFOLDER/dropbox_uploader.sh upload $BAKWP/"$NOW"/backup-files_"$NOW".tar.bz2 $DROPBOX_FOLDER
        echo " > Trying to delete old backup from Dropbox ..." >> $LOG
        $SFOLDER/dropbox_uploader.sh remove /backup-files_"$ONEWEEKAGO".tar.bz2
    else
        echo " > ERROR - No such directory or file" >> $LOG
        ERROR=true
        ERROR_TYPE="TAR ERROR: No such directory or file $BAKWP/$NOW/backup-files_$NOW.tar.bz2"
    fi
  fi
else
  k=0;
  for j in $(find $SITES -maxdepth 1 -type d)
  do
      if [[ "$k" -gt 0 ]]; then
        FOLDER_NAME=$(basename $j)
        if $TAR --exclude '.git' --exclude '*.log' -jcvpf $BAKWP/"$NOW"/backup-"$FOLDER_NAME"_files_"$NOW".tar.bz2 $j; then
            BK_SIZE=$(ls -lah $BAKWP/"$NOW"/backup-"$FOLDER_NAME"_files_"$NOW".tar.bz2 | awk '{ print $5}')
            echo " > Backup created, final size: $BK_SIZE ..." >> $LOG
            echo " > Uploading TAR to Dropbox ..." >> $LOG
            $SFOLDER/dropbox_uploader.sh upload $BAKWP/"$NOW"/backup-"$FOLDER_NAME"_files_"$NOW".tar.bz2 $DROPBOX_FOLDER
            echo " > Trying to delete old backup from Dropbox ..." >> $LOG
            $SFOLDER/dropbox_uploader.sh remove /backup-"$FOLDER_NAME"_files_"$ONEWEEKAGO".tar.bz2
            if [ "$DEL_UP" = true ] ; then
              echo " > Deleting backup from server ..." >> $LOG
              rm -r $BAKWP/"$NOW"/backup-"$FOLDER_NAME"_files_"$NOW".tar.bz2
            fi
        else
            echo " > ERROR - No such directory or file" >> $LOG
            ERROR=true
            ERROR_TYPE="TAR ERROR: No such directory or file $BAKWP/$NOW/backup-"$FOLDER_NAME"_files_$NOW.tar.bz2"
        fi
      fi
      k=$k+1;
  done
fi

### File Check ###
AMOUNT_FILES=`ls -d $BAKWP/"$NOW"/*_files_"$NOW".tar.bz2 | wc -l`
echo " > Number of backup files found: $AMOUNT_FILES ..." >> $LOG

### Deleting old backup files ###
if [ "$DEL_UP" = true ] ; then
  rm -r $BAKWP/$NOW
else
  OLD_BK="$BAKWP/$ONEWEEKAGO/"
  if [ ! -f $OLD_BK ]; then
    echo " > Old backups not found in server ..." >> $LOG
  else
    ### Remove old backup from server ###
    echo " > Deleting old backups from server ..." >> $LOG
    rm -r $BAKWP/$ONEWEEKAGO
  fi
fi

### DUPLICITY ###
if [ "$DUP_BK" = true ] ; then
	### Check if DUPLICITY is installed ###
	DUPLICITY="$(which duplicity)"
	if [ ! -x "${DUPLICITY}" ]; then
	  apt-get install duplicity
	fi
	### Loop in to Directories ###
	for i in $(echo $DUP_FOLDERS | sed "s/,/ /g")
	do
		MANIFEST=`ls -1R $DUP_ROOT$i/ |  grep -i .*.manifest | wc -l`
		if [ $MANIFEST == 0 ]; then
			### If no MANIFEST is found, then create a full Backup ###
			duplicity full -v4 --no-encryption $DUP_SRC_BK$i file://$DUP_ROOT$i
      RETVAL=$?
			echo " > Full Backup of $i OK, and was stored in $DUP_ROOT$i." >> $LOG
		else
			### Else, do an incremantal Backup ###
			duplicity incremental -v4 --no-encryption $DUP_SRC_BK$i file://$DUP_ROOT$i
      RETVAL=$?
			echo " > Incremental Backup of $i OK, and was stored in $DUP_ROOT$i." >> $LOG
      # TODO: Purge old backups
      #duplicity remove-older-than 1M --force $DUP_ROOT/$i
		fi
	done
  [ $RETVAL -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >> $LOG
  [ $RETVAL -ne 0 ] && echo "*** DUPLICITY ERROR ***" >> $LOG

fi

if [ "$ERROR" = true ] ; then
  STATUS_ICON_F="💩"
  STATUS_F="ERROR"
  CONTENT="<b>Server IP: $IP</b><br /><b>$BK_TYPE Backup Error: $ERROR_TYPE<br />Please check log file.</b> <br />"
  COLOR='red'
  echo " > File Backup ERROR: $ERROR_TYPE" >> $LOG
else
  STATUS_ICON_F="✅"
  STATUS_F="OK"
  CONTENT=""
  COLOR='#1DC6DF'
  SIZE_LABEL="Standard Backup file size: <b>$BK_SIZE</b><br />"
  FILES_LABEL='<b>Backup file includes:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
  FILES_INC=""
  echo " > Folders included:" >> $LOG
  for t in $(find $SITES -maxdepth 1 -type d)
  do
      FILES_INC="$FILES_INC $t<br />"
      echo " > $FILES_INC" >> $LOG
  done
  FILES_LABEL_END='</div>';
  echo -e "\e[42m > File Backup OK\e[0m" >> $LOG

  if [ "$DUP_BK" = true ] ; then
    DBK_SIZE=$(du -hs $DUP_ROOT | cut -f1)
    DBK_SIZE_LABEL="Duplicity Backup size: <b>$DBK_SIZE</b><br /><b>Duplicity Backup includes:</b><br />$DUP_FOLDERS"
  fi

fi

HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERTEXT="Files Backup -> $STATUS_F"
HEADERCLOSE='</div>'

BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
BODYCLOSE='</div></div>'

# TODO: el footer debería armarlo el runner u otro script que se dedique a armar la estructura del mail.
FOOTEROPEN='<div style="font-size:10px;float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">'
SCRIPTSTRING="Script Version: $SCRIPT_V by Broobe."
FOOTERCLOSE='</div></div>'

HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$SIZE_LABEL$FILES_LABEL$FILES_INC$FILES_LABEL_END$DBK_SIZE_LABEL$BODYCLOSE
FOOTER=$FOOTEROPEN$SCRIPTSTRING$FOOTERCLOSE

echo $HEADER > $BAKWP/file-bk-$NOW.mail
echo $BODY >> $BAKWP/file-bk-$NOW.mail
echo $FOOTER >> $BAKWP/file-bk-$NOW.mail

export STATUS_F STATUS_ICON_F HTMLOPEN HEADER BODY FOOTER HTMLCLOSE
