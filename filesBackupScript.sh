#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
#############################################################################

### Starting Message ###
echo " > Starting file backup script ..."

### TAR Nginx Config ###
$TAR -jcvpf $BAKWP/$NOW/nginx-$NOW.tar.bz2 $NGINX

### TAR Sites ###
$TAR -jcvpf $BAKWP/$NOW/files-$NOW.tar.bz2  --exclude .git --exclude "*.log" $SITES

### Upload Backup Files ###
echo " > Uploading TAR to Dropbox ..."
$SFOLDER/dropbox_uploader.sh upload $BAKWP/$NOW/nginx-$NOW.tar.bz2 /
$SFOLDER/dropbox_uploader.sh upload $BAKWP/$NOW/files-$NOW.tar.bz2 /
if [ "$DEL_UP" = true ] ; then
  rm -r $BAKWP/$NOW
else
  OLD_BK=$BAKWP/$ONEWEEKAGO/files-$ONEWEEKAGO.tar.bz2
  OLD_BK_NG=$BAKWP/$ONEWEEKAGO/nginx-$ONEWEEKAGO.tar.bz2
  if [ ! -f $OLD_BK ]; then
    echo " > Old backups not found in server ..."
  else
    ### Remove old backup from server ###
    echo " > Deleting old backups from server ..."
    rm -f $OLD_BK
    rm -f $OLD_BK_NG
  fi
fi

### Remove old backups from Dropbox ###
echo " > Trying to delete old backups from Dropbox ..."
$SFOLDER/dropbox_uploader.sh remove /nginx-$ONEWEEKAGO.tar.bz2
$SFOLDER/dropbox_uploader.sh remove /files-$ONEWEEKAGO.tar.bz2

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

### File Check ###
AMOUNT_FILES=`ls -1R $BAKWP/$NOW |  grep -i files-$NOW.tar.bz2 | wc -l`
BACKUPEDLIST_FILES=`ls $BAKWP/$NOW | grep -i files-$NOW.tar.bz2`
echo " > Number of backup files found: $AMOUNT_FILES ..."

##TODO: INCLUIR EN EL MAIL LOS BACKUPS DE DUPLICITY

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
	CONTENT="<b>Server IP: $IP</b><br /><b>Files included on Backup:</b><br />"
  FILES_INC=""
  for t in $(echo $BACKUPEDLIST_FILES | sed "s/,/ /g")
	do
    FILES_INC="$FILES_INC $t<br />"
  done
	COLOR='#1DC6DF'
	echo " > File Backup OK"
fi
HEADERTEXT="$STATUS_ICON $VPSNAME - Files Backup - [$NOWDISPLAY - $STATUS]"
HEADEROPEN1='<html><body><div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF; float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERCLOSE='</div>'
BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
BODYCLOSE='</div>'
FOOTER='<div style="font-size:10px; float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">Broobe Team</div></div></body></html>'
HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$FILES_INC$BODYCLOSE

### Sending Email ###
sendEmail -f no-reply@send.broobe.com -t "servidores@broobe.com" -u "$STATUS_ICON $VPSNAME - Files Backup - [$NOWDISPLAY - $STATUS]" -o message-content-type=html -m "$HEADER $BODY $FOOTER" -s mx.bmailing.com.ar:587 -o tls=yes -xu no-reply@send.broobe.com -xp broobe2020*
