#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.12
#############################################################################

function test_display_functions() {

    test_display
    test_string_remove_color_chars

}

function test_display() {

    log_subsection "Testing display 1"

    display --indent 6 --text "- Testing message DONE" --result "DONE" --color WHITE
    display --indent 6 --text "- Testing message WARNING" --result "WARNING" --color YELLOW
    display --indent 6 --text "- Testing message ERROR" --result "ERROR" --color RED
    display --indent 8 --text "Testing output ERROR" --tcolor RED

    log_subsection "Testing display 2"

    display --indent 6 --text "- Testing message with color" --result "DONE" --color WHITE
    display --indent 8 --text "Testing output DONE" --tcolor WHITE --tstyle CURSIVE
    display --indent 6 --text "- Testing message with color" --result "DONE" --color WHITE
    display --indent 8 --text "Testing output WHITE in ITALIC" --tcolor WHITE --tstyle ITALIC
    display --indent 6 --text "- Testing message with color" --result "WARNING" --color YELLOW
    display --indent 8 --text "Testing output WARNING" --tcolor YELLOW

    log_subsection "Testing display with spinner"

    spinner_start "Testing spinner for 3 seconds"
    sleep 3
    spinner_stop $?
    display --indent 6 --text "- Testing spinner" --result "DONE" --color WHITE

}

function test_string_remove_color_chars() {

    # Test 1
    message1="${YELLOW}- Testing colored message${ENDCOLOR}"
    echo "${message1}"
    colored_test_1=$(_string_remove_color_chars "${message1}")
    echo "${colored_test_1}"

    # Test 2
    message2="- Testing message with colored ${YELLOW}word${ENDCOLOR}"
    echo "${message2}"
    colored_test_2=$(_string_remove_color_chars "${message2}")
    echo "${colored_test_2}"

}
