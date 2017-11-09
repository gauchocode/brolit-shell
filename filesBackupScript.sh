#! /bin/bash
# Autor: broobe. web + mobile development - http://broobe.com
#############################################################################
 
BAKWP="/root/tmp"

if [ ! -d "$BAK" ]
then
    echo "Folder doesn't exist. Creating now"
    mkdir $BAK
    echo "Folder created"
else
    echo "Folder exists"
fi
 
TAR="$(which tar)"
VPSNAME="$HOSTNAME"
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")
 
rm -rf $BAKWP/files-$ONEWEEKAGO.tar.gz
 
cd /var/www/
                            
$TAR -zcvpf $BAKWP/files-$NOW.tar.gz /var/www/
 
cd /root/backup-scripts/
 
./dropbox_uploader.sh upload $BAKWP/files-$NOW.tar.gz /
./dropbox_uploader.sh remove /files-$ONEWEEKAGO.tar.gz
 
AMOUNT2=`ls -1R $BAKWP/ |  grep -i .*$NOW.tar.gz | wc -l`
BACKUPEDLIST2=`ls $BAKWP/ | grep -i .*$NOW.tar.gz` 
 
#if [ 1 -ne $AMOUNT2 ]; then
#STATUS="ERROR"
#SUBJECT="DROBI-VPS [$NOWDISPLAY] - filesBackups - OK"
#CONTENT="<b>Ocurrio un error. Los archivos incluidos en el backup, son menos que la cantidad de esperada</b> <br />"
#COLOR='red'
# 
#else
#STATUS="OK"
#SUBJECT="DROBI-VPS [$NOWDISPLAY] - filesBackups - OK"
#CONTENT="<b>Los archivos incluidos en el backup diario son:</b><br />$BACKUPEDLIST2"
#COLOR='#1DC6DF'
#fi
#HEADEROPEN1='<html><body><div style="float:left;width:500px"><div style="font-size:13px;color:#FFF; float:left;font-family: Verdana, Tahoma, Helvetica, Arial;line-height:31px;background:'
#HEADEROPEN2='; padding-left:5px;width:500px; height:20px">'
#HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
#HEADERCLOSE='</div>'
#BODYOPEN='<div style="color:#000;font-size:10px; float:left;font-family: Verdana, Tahoma, Helvetica, Arial;background:#D8D8D8;padding-left:5px;width:500px; height:130px">'
#BODYCLOSE='</div>'
#FOOTER='<div style="font-size:10px; float:left;font-family: Verdana, Tahoma, Helvetica, Arial;text-align:right; padding-right:5px;width:500px; height:20px">Broobe Team</div></div></body></html>'
# 
# 
#HEADER=$HEADEROPEN$SUBJECT$HEADERCLOSE
# 
#BODY=$BODYOPEN$CONTENT$BODYCLOSE
# 
#sendEmail -f admin@broobe.com -t "soporte@broobe.com" -u "DROBI-VPS-BACKUPS [Files] - [$STATUS] ($NOWDISPLAY)" -m "$HEADER $BODY $FOOTER" -s smtp.gmail.com -o tls=yes -xu admin@broobe.com -xp br00b34dm1n
