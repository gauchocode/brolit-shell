#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.41
################################################################################

function get_function_list () {
    env -i bash --noprofile --norc -c '
    source "'"$1"'"
    typeset -f |
    grep '\''^[^{} ].* () $'\'' |
    awk "{print \$1}" |
    while read -r fcn_name; do
        type "$fcn_name" | head -n 1 | grep -q "is a function$" || continue
        echo "$fcn_name"
    done
'
}

for function_name in $(get_function_list libs/apps/certbot_helper.sh); do
    echo "${function_name}"
done