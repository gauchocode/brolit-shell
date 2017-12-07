#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.6
#############################################################################

### Starting Message ###
echo " > Starting file backup script ..."

### TAR Webserver Config Files ###
$TAR -jcvpf $BAKWP/$NOW/webserver-config-files-$NOW.tar.bz2 $WSERVER

### TAR Sites Folders ###
$TAR --exclude '.git' --exclude '*.log' -jcvpf $BAKWP/$NOW/backup-files-$NOW.tar.bz2 $SITES
BK_SIZE=$(ls -lah $BAKWP/$NOW/backup-files-$NOW.tar.bz2 | awk '{ print $5}')
echo " > Backup created, final size: $BK_SIZE ..."

### File Check ###
#AMOUNT_FILES=`ls -1R $BAKWP/$NOW |  grep -i *files-$NOW.tar.bz2 | wc -l`
AMOUNT_FILES=`ls -d $BAKWP/$NOW/*-files-$NOW.tar.bz2 | wc -l`
echo " > Number of backup files found: $AMOUNT_FILES ..."

### Upload Backup Files ###
echo " > Uploading TAR to Dropbox ..."
$SFOLDER/dropbox_uploader.sh upload $BAKWP/$NOW/webserver-config-files-$NOW.tar.bz2 $DROPBOX_FOLDER
$SFOLDER/dropbox_uploader.sh upload $BAKWP/$NOW/backup-files-$NOW.tar.bz2 $DROPBOX_FOLDER
if [ "$DEL_UP" = true ] ; then
  rm -r $BAKWP/$NOW
else
  OLD_BK=$BAKWP/$ONEWEEKAGO/backup-files-$ONEWEEKAGO.tar.bz2
  if [ ! -f $OLD_BK ]; then
    echo " > Old backups not found in server ..."
  else
    ### Remove old backup from server ###
    echo " > Deleting old backups from server ..."
    rm -r $BAKWP/$ONEWEEKAGO
  fi
fi

### Remove old backups from Dropbox ###
echo " > Trying to delete old backups from Dropbox ..."
if [ "$DROPBOX_FOLDER" != "/" ] ; then
  $SFOLDER/dropbox_uploader.sh remove $DROPBOX_FOLDER/webserver-config-files-$ONEWEEKAGO.tar.bz2
  $SFOLDER/dropbox_uploader.sh remove $DROPBOX_FOLDER/backup-files-$ONEWEEKAGO.tar.bz2
else
  $SFOLDER/dropbox_uploader.sh remove /webserver-config-files-$ONEWEEKAGO.tar.bz2
  $SFOLDER/dropbox_uploader.sh remove /backup-files-$ONEWEEKAGO.tar.bz2
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
			echo " > Full Backup of $i OK, and was stored in $DUP_ROOT$i."
		else
			### Else, do an incremantal Backup ###
			duplicity incremental -v4 --no-encryption $DUP_SRC_BK$i file://$DUP_ROOT$i
			echo " > Incremental Backup of $i OK, and was stored in $DUP_ROOT$i."
		fi
	done
fi

##TODO: INCLUIR EN EL MAIL LOS BACKUPS DE DUPLICITY

### Disk Usage ###
DISK_UFL=$( df -h | grep "$MAIN_VOL" | awk {'print $5'} )

### Configuring Email ###
if [ 1 -ne $AMOUNT_FILES ]; then
  STATUS_ICON="💩"
	STATUS="ERROR"
	CONTENT="<b>Server IP: $IP</b><br /><b>Backup with errors.<br />Please check log file.</b> <br />"
	COLOR='red'
	echo " > File Backup ERROR"
else
  STATUS_ICON="✅"
	STATUS="OK"
  CONTENT="<b>Server IP: $IP</b><br />"
  SIZE="Backup file size: <b>$BK_SIZE</b><br />"
  SPACE="Disk usage before the database backup: <b>$DISK_U</b>.<br />Disk usage after the database backup: <b>$DISK_UFL</b>.<br />"
  FILES_LABEL='<b>Backup file includes:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
  FILES_INC=""
  echo " > Folders included:"
  for t in $(find $SITES -maxdepth 1 -type d)
  do
      FILES_INC="$FILES_INC $t<br />"
      echo " > $t"
  done
	COLOR='#1DC6DF'
	echo " > File Backup OK"
fi
HEADERTEXT="$STATUS_ICON $VPSNAME - Files Backup - [$NOWDISPLAY - $STATUS]"
HEADEROPEN1='<html><body><div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERCLOSE='</div>'
BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
BODYCLOSE='</div></div>'
FOOTEROPEN='<div style="font-size:10px;float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">'
SCRIPTSTRING="Script Version: $SCRIPT_V by Broobe."
FOOTERCLOSE='</div></div></body></html>'
HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$SIZE$SPACE$FILES_LABEL$FILES_INC$BODYCLOSE
FOOTER=$FOOTEROPEN$SCRIPTSTRING$FOOTERCLOSE

### Sending Email ###
sendEmail -f $SMTP_U -t "servidores@broobe.com" -u "$STATUS_ICON $VPSNAME - Files Backup - [$NOWDISPLAY - $STATUS]" -o message-content-type=html -m "$HEADER $BODY $FOOTER" -s $SMTP_SERVER -o tls=$SMTP_TLS -xu $SMTP_U -xp $SMTP_P
