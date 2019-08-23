#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
################################################################################

mail_header() {
    SRV_HEADEROPEN='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:#1DC6DF;padding:0 0 10px 10px;width:100%;height:30px">'
    SRV_HEADERTEXT="Server Info"
    SRV_HEADERCLOSE='</div>'
    SRV_HEADER=${SRV_HEADEROPEN}${SRV_HEADERTEXT}${SRV_HEADERCLOSE}
}

#mail_body_generator() {
#
#}

mail_footer() {
    HTMLOPEN='<html><body>'
    HTMLCLOSE='</body></html>'
}
