#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 3.0-rc01
################################################################################
#
# Ref: https://linuxize.com/post/how-to-install-pip-on-ubuntu-18.04/
#

################################################################################

python_installer() {
    apt install python python-pip
    pip install setuptools

}

#python_module_check_installation() {
#    pip install wetransferpy
#
#}

python_module_install_wetransfer() {
    #https://github.com/sirowain/py-transmat

    pip install py3wetransfer
    pip install transmat

}