#!/bin/bash
#==========================================================================
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#==========================================================================
# 
# IMPORTANT: internal tool
# 
# Description:
#   This script was written for download builds from PVT server.
#
# Author: Askeing fyen@mozilla.com
# History:
#   2013/08/16 Askeing: v1.0 First release.
#   2013/09/25 Askeing: added v1.2.0 and changed the seqence of flash mode.
#   2013/09/25 Askeing: removed the pwd of wget when using command mode.
#   2013/09/26 Askeing: fixed the HTTP_PWD issue.
#   2013/10/07 Al: added buildID support on Mac.
#   2013/10/09 Askeing: added buildID support on Linux.
#   2013/10/09 Askeing: modified the seqence of flash mode in command mode.
#   2013/10/09 Askeing: added download failed message for wget.
#   2013/10/09 Askeing: rename -b|--build to -b|--buildid.
#   2013/10/11 Askeing: updated -f|--flash to -f|--full.
#   2013/10/11 Askeing: added check_build_id function.
#   2013/11/13 Askeing: if flash gecko, then un-install com-ril. set KEEP_COMRIL=1 will skip this step.
#   2013/11/13 Askeing: removed KEEP_COMRIL, set UNINSTALL_COMRIL=true to un-install com-ril.
#   2013/11/28 Askeing: DEBUG=1 will by pass auto checkout master and auto pull.
#   2013/12/13 Askeing: remove DEBUG and auto pull.
#   2014/02/06 Askeing: enable local cache by default, USE_LOCAL=false to force download from pvt.
#   2014/02/06 Askeing: added DL_HOME to specify download folder.
#   2014/07/31 Askeing: End of maintenance.
#
#==========================================================================

echo -e "This tool will end of maintenace from now.\nPlease run './flash_pvt.py -h' to get the usage of new tool.\n"
sleep 5

####################
# Parameter Flags  #
####################
## customize flags
DL_HOME=${DL_HOME:="pvt"}
USE_LOCAL=${USE_LOCAL:=true}
USE_LOCAL_LATEST=${USE_LOCAL_LATEST:=false}
## inside flags
VERY_SURE=false
WGET_AUTHN=false
INTERACTION_WINDOW=false
ADB_DEVICE="Device"
DEVICE_NAME=""
VERSION_NAME=""
BUILD_ID=""
FLASH_FULL=false
FLASH_GAIA=false
FLASH_GECKO=false
FLASH_FULL_IMG_FILE=""
FLASH_GAIA_FILE=""
FLASH_GECKO_FILE=""
TARGET_ID=-1
FLASH_USR_IF_POSSIBLE=false
FLASH_ENG_IF_POSSIBLE=false
FLASH_USER_ENG_DONE=false

####################
# Functions        #
####################

## Show usage
function helper(){
    echo -e "This script was written for download builds from PVT server.\n"
    echo -e "Usage: ./auto_flash_from_pvt.sh [parameters]"
    echo -e "  -v|--version\tthe target build version."
    echo -e "  -d|--device\tthe target device."
    echo -e "  -s <serial number>\tdirects command to device with the given serial number."
    echo -e "  -f|--full\tflash full image into device."
    echo -e "  -g|--gaia\tshallow flash gaia into device."
    echo -e "  -G|--gecko\tshallow flash gecko into device."
    echo -e "  --usr\tspecify User(USR) build."
    echo -e "  --eng\tspecify Engineer(ENG) build."
    echo -e "  -b|--buildid\tspecify target build YYYYMMDDhhmmss"
    echo -e "  -w\t\tinteraction GUI mode."
    echo -e "  -y\t\tAssume \"yes\" to all questions"
    echo -e "  -h|--help\tdisplay help."
    echo -e "Environment:"
    echo -e "  HTTP_USER={username} \tset LDAP account. (you can fill it into .ldap file)"
    echo -e "  HTTP_PWD={password} \tset LDAP password. (you can fill it into .ldap file)"
    echo -e "  UNINSTALL_COMRIL=true \tuninstall the com-ril when shallow flash gecko. (Keep com-ril by default)"
    echo -e "  DL_HOME={download_dir_home}\tspecify download folder. Default=./pvt"
    echo -e "  USE_LOCAL=false \tforce download target builds (with Build ID) from PVT server. Default=true"
    echo -e "  USE_LOCAL_LATEST=true\tdo not download Latest builds from PVT server. Default=false"
    echo -e "Example:"
    echo -e "  Flash by interaction GUI mode\t\t\t\t./auto_flash_from_pvt.sh -w"
    case `uname` in
        "Linux")
            echo -e "  Flash inari v1.2.0 ENG image\t\t\t\t./auto_flash_from_pvt.sh --version=v1.2.0 --device=inari --full --eng"
            echo -e "  Flash buri master USR build 20131116040201 gaia/gecko\t./auto_flash_from_pvt.sh -vmaster -dburi -b20131116040201 -g -G --usr";;
        "Darwin")
            echo -e "  Flash inari v1.2.0 ENG image\t\t\t\t./auto_flash_from_pvt.sh --version v1.2.0 --device inari --full --eng"
            echo -e "  Flash buri master USR build 20131116040201 gaia/gecko\t./auto_flash_from_pvt.sh -v master -d buri -b 20131116040201 -g -G --usr";;
    esac
    exit 0
}

## Show the available version info
function version_info(){
    echo -e "Available version:"
    echo -e "  200|v2.0.0"
    echo -e "  140|v1.4.0"
    echo -e "  130|v1.3.0"
    echo -e "  120|v1.2.0"
    echo -e "  110hd|v1.1.0hd"
    echo -e "  110|v1train"
    echo -e "  101|v1.0.1"
    echo -e "  0|master"
}

## Select the version
function version() {
    local_ver=$1
    case "$local_ver" in
        200|v2.0.0) VERSION_NAME="v200";;
        140|v1.4.0) VERSION_NAME="v140";;
        130|v1.3.0) VERSION_NAME="v130";;
        120|v1.2.0) VERSION_NAME="v120";;
        110hd|v1.1.0hd) VERSION_NAME="v110hd";;
        110|v1train) VERSION_NAME="v110";;
        101|v1.0.1) VERSION_NAME="v101";;
        0|master) VERSION_NAME="master";;
        *) version_info; exit -1;;
    esac
    
}

## Show the available device info
function device_info(){
    echo -e "Available device:"
    echo -e "  unagi"
    echo -e "  hamachi"
    echo -e "  buri"
    echo -e "  inari"
    echo -e "  leo"
    echo -e "  helix"
    echo -e "  wasabi"
    echo -e "  tarako"
    echo -e "  nexus4"
    echo -e "  flame"
}

## Select the device
function device() {
    local_ver=$1
    case "$local_ver" in
        unagi) DEVICE_NAME="unagi";;
        hamachi) DEVICE_NAME="hamachi";;
        buri) DEVICE_NAME="hamachi";;
        inari) DEVICE_NAME="inari";;
        leo) DEVICE_NAME="leo";;
        helix) DEVICE_NAME="helix";;
        wasabi) DEVICE_NAME="wasabi";;
        tarako) DEVICE_NAME="tarako";;
        nexus4) DEVICE_NAME="nexus4";;
        flame) DEVICE_NAME="flame";;
        *) device_info; exit -1;;
    esac
}

## Device List ##
#  * unagi      #
#  * hamachi    #
#  * inari      #
#  * leo        #
#  * helix      #
#  * wasabi     #
#  * nexus 4    #
#  * flame      #
# ############# #

function select_device_dialog() {
    dialog --backtitle "Select Device from PVT Server " --title "Device List" --menu "Move using [UP] [DOWN],[Enter] to Select" \
    18 80 10 \
    "unagi" "Unagi Device (Not Supported)" \
    "hamachi" "Buri/Hamachi Device" \
    "inari" "Ikura/Inari Device" \
    "leo" "Leo Device" \
    "helix" "Helix Device" \
    "wasabi" "Wasabi Device" \
    "tarako" "Tarako Device" \
    "nexus4" "Nexus 4 Device" \
    "flame" "Flame/OpenC Device" 2>${TMP_DIR}/menuitem_device
    ret=$?
    if [ ${ret} == 1 ]; then
        echo "" && echo "byebye." && exit 0
    fi
    menuitem_device=`cat ${TMP_DIR}/menuitem_device`
    case $menuitem_device in
        "") echo ""; echo "byebye."; exit 0;;
        *) device $menuitem_device;;
    esac
}

function select_device_dialog_mac() {
    device_option_list='{"unagi","hamachi","inari","leo","helix","wasabi","tarako","nexus4","flame"}'
    eval ret=\$\(osascript -e \'tell application \"Terminal\" to choose from list $device_option_list with title \"Choose Device\"\'\)
    ret=${ret#*text returned:}
    ret=${ret%, button returned:*}
    device ${ret}
    if [[ ${ret} == false ]]; then
        echo ""
        echo "byebye"
        exit 0
    fi
}

## Version List ##
#  Version list will load from .PVT_DL_LIST #

function select_version_dialog() {
    MENU_VERSION_LIST=""
    for (( COUNT=0 ; COUNT<${DL_SIZE} ; COUNT++ ))
    do
        KEY=DL_${COUNT}_NAME
        eval VALUE=\$$KEY
        ## if Name contain the DEVICE_NAME, add into List
        if [[ ${VALUE} == *"$DEVICE_NAME" ]]; then
            echo -e "${COUNT}) ${VALUE}"
            MENU_VERSION_LIST+=" ${COUNT} \"${VALUE}\""
        fi
    done
    
    dialog --backtitle "Select Device from PVT Server " --title "Device List" --menu "Move using [UP] [DOWN],[Enter] to Select" \
    18 80 10 ${MENU_VERSION_LIST} 2>${TMP_DIR}/menuitem_version
    ret=$?
    if [ ${ret} == 1 ]; then
        echo "" && echo "byebye." && exit 0
    fi
    menuitem_version=`cat ${TMP_DIR}/menuitem_version`
    case $menuitem_version in
        "") echo ""; echo "byebye."; exit 0;;
        *) TARGET_ID=$menuitem_version; NAME_KEY=DL_${TARGET_ID}_NAME; eval TARGET_NAME=\$$NAME_KEY; VERSION_NAME=`echo $TARGET_NAME | sed "s,PVT\.,,g;s,\.$DEVICE_NAME,,g"`;;
    esac
}

function select_version_dialog_mac() {
    option_list=""
    for (( COUNT=0 ; COUNT<${DL_SIZE} ; COUNT++ ))
    do
        KEY=DL_${COUNT}_NAME
        eval VALUE=\$$KEY
        if [[ ${VALUE} == *"$DEVICE_NAME" ]]; then
            option_list=$option_list,\"${COUNT}-${VALUE}\"
        fi
    done
    local_option_list=${option_list#,*}
    eval ret=\$\(osascript -e \'tell application \"Terminal\" to choose from list \{$local_option_list\} with title \"Select Version\"\'\)
    TARGET_ID=${ret%%-*}
    if [[ ${ret} == false ]]; then
        echo ""
        echo "byebye"
        exit 0
    fi
}

## adb with flags
function run_adb() {
    # TODO: Bug 875534 - Unable to direct ADB forward command to inari devices due to colon (:) in serial ID
    # If there is colon in serial number, this script will have some warning message.
    adb $ADB_FLAGS $@
}

## Un-install Com-RIL
function uninstall_comril() {
    if [ -f ./install_comril.sh ]; then
        echo "Un-install com-ril..."
        bash ./install_comril.sh -u -y
        run_adb wait-for-device # wait in this function, then goto next step.
    fi
}

## wget with flags
function run_wget() {
    if [ ${WGET_AUTHN} != true ]; then
        run_wget_authn
    fi

    echo "WGET: " $@
    if [ "${HTTPUser}" != "" ] && [ "${HTTPPwd}" != "" ]; then
        wget --http-user="${HTTPUser}" --http-passwd="${HTTPPwd}" $@
    else
        wget $@
    fi
}

## Prepare the authn of web site
function run_wget_authn() {
    source .ldap
    if [ "$HTTP_USER" != "" ]; then
        echo -e "Load account [$HTTP_USER] from .ldap"
    fi
    if [ "$HTTP_PWD" != "" ]; then
        echo -e "Load password from .ldap"
    fi

    if [[ ${INTERACTION_WINDOW} == false ]]; then
        set_wget_acct_pwd
    else
        case `uname` in
            "Linux") set_wget_acct_pwd_dialog;;
            "Darwin") set_wget_acct_pwd_dialog_mac;;
        esac
    fi
    WGET_AUTHN=true
}

## setup the http user account and passwd
function set_wget_acct_pwd() {
    if [ "$HTTP_USER" != "" ]; then
        HTTPUser=$HTTP_USER
    else
        read -p "Enter HTTP Username (LDAP): " HTTPUser
    fi
    if [ "$HTTP_PWD" != "" ]; then
        HTTPPwd=$HTTP_PWD
    else
        read -s -p "Enter HTTP Password (LDAP): " HTTPPwd
    fi
    echo ""
}

function set_wget_acct_pwd_dialog() {
    if [ "$HTTP_USER" != "" ]; then
        HTTPUser=$HTTP_USER
    else
        dialog --backtitle "Setup WGET" --title "HTTP User Name" --inputbox "\n\nEnter HTTP Username (LDAP)\n\nMove using [Tab] to Select\n" 15 80 2>${TMP_DIR}/menuitem_wgetacct
        ret=$?
        if [ ${ret} == 1 ]; then
            echo "" && echo "byebye." && exit 0
        fi
        menuitem_wgetacct=`cat ${TMP_DIR}/menuitem_wgetacct`
        case $menuitem_wgetacct in
            "") echo ""; echo "byebye."; exit 0;;
            *) HTTPUser=$menuitem_wgetacct;;
        esac
    fi
    if [ "$HTTP_PWD" != "" ]; then
        HTTPPwd=$HTTP_PWD
    else
        dialog --backtitle "Setup WGET" --title "HTTP Password" --insecure --passwordbox "\n\nEnter HTTP Password (LDAP)\n\nMove using [Tab] to Select" 15 80 2>${TMP_DIR}/menuitem_wgetpwd
        ret=$?
        if [ ${ret} == 1 ]; then
            echo "" && echo "byebye." && exit 0
        fi
        menuitem_wgetpwd=`cat ${TMP_DIR}/menuitem_wgetpwd`
        case $menuitem_wgetpwd in
            "") echo ""; echo "byebye."; exit 0;;
            *) HTTPPwd=$menuitem_wgetpwd;;
        esac
    fi
}

function set_wget_acct_pwd_dialog_mac() {
    if [ "$HTTP_USER" != "" ]; then
        HTTPUser=$HTTP_USER
    else
        ret=$(osascript -e 'tell application "Terminal" to display dialog "Enter LDAP account" default answer "" with title "Account Info"')
        ret=${ret#*text returned:}
        ret=${ret%, button returned:*}
        HTTPUser=${ret}
    fi
    if [ "$HTTP_PWD" != "" ]; then
        HTTPPwd=$HTTP_PWD
    else
        ret=$(osascript -e 'tell application "Terminal" to display dialog "Enter LDAP password" default answer "" with hidden answer with title "Account Info"')
        ret=${ret#*text returned:}
        ret=${ret%, button returned:*}
        HTTPPwd=${ret}
    fi
    if [ -z '$HTTPUser' ] || [ -z '$HTTPPwd' ] ; then
        echo ""
        echo "byebye"
        exit 0
    fi
}

## install dialog package for interaction GUI mode
function check_install_dialog() {
    if ! which dialog > /dev/null; then
        read -p "Package \"dialog\" not found! Install? [Y/n]" REPLY
        test "$REPLY" == "n" || test "$REPLY" == "N" && echo "byebye." && exit 0
        sudo apt-get install dialog
    fi
}

## Create the message for make sure dialog
function create_make_sure_msg() {
    MAKE_SURE_MSG="\n"
    MAKE_SURE_MSG+="Your Target Build: ${TARGET_NAME}\n"
    MAKE_SURE_MSG+="URL:  ${TARGET_URL}\n"
    MAKE_SURE_MSG+="ENG Ver: ${FLASH_ENG}\n"
    MAKE_SURE_MSG+="Flash: "
    if [[ ${FLASH_FULL} == true ]]; then
        MAKE_SURE_MSG+="Full Image."
    else
        if [[ ${FLASH_GAIA} == true ]]; then
            MAKE_SURE_MSG+="Gaia, "
        fi
        if [[ ${FLASH_GECKO} == true ]]; then
            MAKE_SURE_MSG+="Gecko, "
        fi
    fi
}

## check the build id should be 14 digits
function check_build_id() {
    if [[ ${BUILD_ID} == "" ]]; then
        echo "Please enter build id." &&
        echo "Try '--help' for more information." &&
        exit 0
    fi

    ## BUILD_ID only can contains [0-9]
    VERIFY_BUILDID=`echo "$BUILD_ID" | awk '$0 ~/[^0-9]/ { print "TRUE" }'`
    if [[ ${VERIFY_BUILDID} == "TRUE" ]]; then
        echo "BUILD_ID ($BUILD_ID) should be 14 digits" &&
        exit 0
    fi

    if [ ${#BUILD_ID} != 14 ]; then
        echo "BUILD_ID ($BUILD_ID) should be 14 digits" &&
        exit 0
    fi
}

function replace_url_for_build_id() {

    ## Replace latest/ with path to BUILD ID when flashing a pvt nightly build
    if [[ ${BUILD_ID} != "" && ${TARGET_URL} =~ "nightly" ]]; then
        check_build_id
        TARGET_URL=${TARGET_URL%latest/}${BUILD_ID:0:4}/${BUILD_ID:4:2}/${BUILD_ID:0:4}-${BUILD_ID:4:2}-${BUILD_ID:6:2}-${BUILD_ID:8:2}-${BUILD_ID:10:2}-${BUILD_ID:12:2}/
    fi

    ## Replace latest/ with BUILD ID folder when flashing a tinderbox build
    if [[ ${BUILD_ID} != "" && ${TARGET_URL} =~ "tinderbox-builds" ]]; then
        check_build_id
        TARGET_URL=${TARGET_URL%latest/}${BUILD_ID}/
    fi

    if [[ ${FLASH_GECKO} == true ]]; then
        # if no local gecko, latest build, or not USE_LOCAL, then check gecko name from website.
        LOCAL_GECKO=`ls ${DL_DIR} | grep b2g-.*\.android-arm\.tar\.gz` || echo "There is no local cache."
        if [ ! -f ${DL_DIR}/${LOCAL_GECKO} ] || [[ ${DOWNLOAD_LATEST} == true ]] || [[ ${USE_LOCAL} != true ]]; then
            ## Find gecko tar file name for --buildid option
            run_wget -qO ${TMP_DIR}/page ${TARGET_URL}
            SOURCE=`cat ${TMP_DIR}/page | grep b2g-.*\.android-arm\.tar\.gz`
            TARGET_GECKO=`echo ${SOURCE} | sed 's/.*b2g-/b2g-/' | sed 's/gz.*/gz/'`
        # there is local gecko, then replace TARGET_GECKO.
        else
            TARGET_GECKO=${LOCAL_GECKO}
        fi
    fi
}

## Prepare Download Folder
function prepare_download_folder() {
    DL_DIR_USR_ENG="USR"
    if [[ "$FLASH_ENG" == true ]]; then
        DL_DIR_USR_ENG="ENG"
    fi

    DL_DIR=${TMP_DIR}
    if [[ ${BUILD_ID} != "" ]]; then
        check_build_id
        DL_DIR=${DL_HOME}/${DEVICE_NAME}/${VERSION_NAME}/${DL_DIR_USR_ENG}/${BUILD_ID}
        # mkdir if there is no folder
        if [ ! -d ${DL_DIR} ]; then
            mkdir -p ${DL_DIR}
        fi
        # remove files if not USE_LOCAL
        if [[ ${USE_LOCAL} != true ]]; then
            if [[ ${FLASH_FULL} == true ]]; then
                rm -f ${DL_DIR}/${TARGET_IMG}
            else
                if [[ ${FLASH_GAIA} == true ]]; then
                    rm -f ${DL_DIR}/${TARGET_GAIA}
                fi
                if [[ ${FLASH_GECKO} == true ]]; then
                    rm -f ${DL_DIR}/${TARGET_GECKO}
                fi
            fi
        fi
    else
        # always clear files for latest build
        DL_DIR=${DL_HOME}/${DEVICE_NAME}/${VERSION_NAME}/${DL_DIR_USR_ENG}/latest
        if [[ ${USE_LOCAL_LATEST} != true ]]; then
            rm -rf ${DL_DIR}/*
            mkdir -p ${DL_DIR}
            DOWNLOAD_LATEST=true
        fi
    fi
}

## make sure user want to flash/shallow flash
function make_sure() {
    read -p "Are you sure you want to flash your device? [y/N]" isFlash
    test "$isFlash" != "y" && test "$isFlash" != "Y" && echo "byebye." && exit 0
}

function make_sure_dialog() {
    ## Build ID support
    if [[ ${BUILD_ID} == "" ]]; then
        dialog --backtitle "Latest Build or Enter Build ID" --title "Selection" --yesno "\n\n\nDo you want to flash the latest build? \n\nClick [No] to enter the Build ID (YYYYMMDDhhmmss)." 15 80 2>${TMP_DIR}/menuitem_latestbuild
        ret=$?
        ## Enter BuildID
        if [ ${ret} == 1 ]; then
            dialog --backtitle "Latest Build or Enter Build ID" --title "Enter Build ID" --inputbox "\n\nEnter the Build ID you want to flash (YYYYMMDDhhmmss)\n\nMove using [Tab] to Select\n" 15 80 2>${TMP_DIR}/menuitem_buildid
            ret=$?
            if [ ${ret} == 1 ]; then
                echo "" && echo "byebye." && exit 0
            fi
            menuitem_buildid=`cat ${TMP_DIR}/menuitem_buildid`
            case $menuitem_buildid in
                "") echo ""; echo "byebye."; exit 0;;
                *) BUILD_ID=$menuitem_buildid;;
            esac
        fi
    fi

    prepare_download_folder
    replace_url_for_build_id
    create_make_sure_msg
    MAKE_SURE_MSG+="\n\nAre you sure you want to flash your device?"
    dialog --backtitle "Confirm the Information" --title "Confirmation" --yesno "${MAKE_SURE_MSG}" 18 80 2>${TMP_DIR}/menuitem_makesure
    ret=$?
    if [ ${ret} == 1 ]; then
        echo "" && echo "byebye." && exit 0
    fi
}

function make_sure_dialog_mac() {
    ret=$(osascript -e 'tell application "Terminal" to display dialog "Do you want to flash the latest build?\n Yes-Latest; No-Enter Build ID" buttons {"Cancel", "No", "Yes"} default button 3 with icon caution')
    if [ "${ret##*:}" == "No" ]; then
        ret=$(osascript -e 'tell application "Terminal" to display dialog "Enter the Build ID you want to flash (YYYYMMDDhhmmss)" default answer "" with title "Build Info"')
        ret=${ret#*text returned:}
        ret=${ret%, button returned:*}
        BUILD_ID=${ret}
        # create DL folder for builds with Build ID
        prepare_download_folder
        replace_url_for_build_id
    elif [[ "${ret##*:}" != "Yes" ]]; then
        echo "" && echo "byebye" && exit 0
    fi
    # latest build also need to create DL folder
    prepare_download_folder
}

## Loading the download list
function load_list() {
    PVT_DL_LIST=.PVT_DL_LIST.conf
    if [ -f $PVT_DL_LIST ]; then
        . $PVT_DL_LIST
    else
        echo "Cannot found the ${PVT_DL_LIST} file."
        exit -1
    fi
}

## Print download list
function print_list() {
    echo "Available Builds:"
    for (( COUNT=0 ; COUNT<${DL_SIZE} ; COUNT++ ))
    do
        KEY=DL_${COUNT}_NAME
        eval VALUE=\$$KEY
        echo -e "  ${COUNT}) ${VALUE}"
    done
}

## Select build
function select_build() {
    print_list
    while [[ ${TARGET_ID} -lt 0 ]] || [[ ${TARGET_ID} -ge ${DL_SIZE} ]]; do
        read -p "What do you want to flash into your device? [Q to exit]" TARGET_ID
        test ${TARGET_ID} == "q" || test ${TARGET_ID} == "Q" && echo "byebye." && exit 0
    done
}

function select_build_dialog() {
    MENU_FLAG=""
    for (( COUNT=0 ; COUNT<${DL_SIZE} ; COUNT++ ))
    do
        KEY=DL_${COUNT}_NAME
        eval VALUE=\$$KEY
        MENU_FLAG+=" ${COUNT} \"${VALUE}\""
    done
    dialog --backtitle "Select Build from PVT Server " --title "Download List" --menu "Move using [UP] [DOWN],[Enter] to Select" \
    18 80 10 ${MENU_FLAG} 2>${TMP_DIR}/menuitem_build
    ret=$?
    if [ ${ret} == 1 ]; then
        echo "" && echo "byebye." && exit 0
    fi
    menuitem_build=`cat ${TMP_DIR}/menuitem_build`
    case $menuitem_build in
        "") echo ""; echo "byebye."; exit 0;;
        *) TARGET_ID=$menuitem_build;;
    esac
}

function select_build_dialog_mac() {
    option_list=""
    for (( COUNT=0 ; COUNT<${DL_SIZE} ; COUNT++ ))
    do
        KEY=DL_${COUNT}_NAME
        eval VALUE=\$$KEY

        option_list=$option_list,\"${COUNT}-${VALUE}\"
    done
    local_option_list=#{option_list#,*}
    eval ret=\$\(osascript -e \'tell application \"Terminal\" to choose from list \{$local_option_list\} with title \"Select Build\"\'\)
    echo $ret
    TARGET_ID=${ret%%-*}
    if [ -z "$TARGET_ID" ]; then
        echo "" && echo "byebye." && exit 0
    fi
}

## Select User or Eng build
function if_has_eng_build() {
    TARGET_HAS_ENG=false
    KEY=DL_${TARGET_ID}_ENG
    eval VALUE=\$$KEY
    if [[ $VALUE == true ]]; then
        TARGET_HAS_ENG=true
    fi
}

function select_user_eng_build() {
    while [[ ${FLASH_USER_ENG_DONE} == false ]]; do
        echo "User or Eng build:"
        echo "  1) User build"
        echo "  2) Engineer build"
        read -p "What do you want to flash? [Q to exit]" FLASH_USER_ENG
        test ${FLASH_USER_ENG} == "q" || test ${FLASH_USER_ENG} == "Q" && echo "byebye." && exit 0
        case ${FLASH_USER_ENG} in
            1) FLASH_ENG=false; FLASH_USER_ENG_DONE=true;;
            2) FLASH_ENG=true; FLASH_USER_ENG_DONE=true;;
        esac
    done
}

function select_user_eng_build_dialog() {
    if [[ ${FLASH_USER_ENG_DONE} == false ]]; then
        dialog --backtitle "Select Build from PVT Server " --title "User or Engineer Build" --menu "Move using [UP] [DOWN],[Enter] to Select" \
        18 80 10 1 "User build" 2 "Engineer build" 2>${TMP_DIR}/menuitem_usereng
        ret=$?
        if [ ${ret} == 1 ]; then
            echo "" && echo "byebye." && exit 0
        fi
        menuitem_usereng=`cat ${TMP_DIR}/menuitem_usereng`
        case $menuitem_usereng in
            "") echo ""; echo "byebye."; exit 0;;
            1) FLASH_ENG=false; FLASH_USER_ENG_DONE=true;;
            2) FLASH_ENG=true; FLASH_USER_ENG_DONE=true;;
        esac
    fi
}

function select_user_eng_build_dialog_mac() {
    if [[ ${TARGET_HAS_ENG} == true ]]; then
        ret=$(osascript -e 'tell application "Terminal" to choose from list {"1-User Build", "2-Engineer Build"} with title "Choose build type"')
        case ${ret%-*} in
            1) FLASH_ENG=false; FLASH_USER_ENG_DONE=true;;
            2) FLASH_ENG=true; FLASH_USER_ENG_DONE=true;;
        esac
        if [ -z "$ret" ]; then
            echo "" && echo "byebye." && exit 0
        fi
    fi
}

## Select flash mode
function select_flash_mode() {
    # if there are no flash flag, then ask
    GAIA_KEY=DL_${TARGET_ID}${ENG_FLAG}_GAIA
    eval GAIA_VALUE=\$$GAIA_KEY
    GECKO_KEY=DL_${TARGET_ID}${ENG_FLAG}_GECKO
    eval GECKO_VALUE=\$$GECKO_KEY
    IMAGE_KEY=DL_${TARGET_ID}${ENG_FLAG}_IMG
    eval IMAGE_VALUE=\$$IMAGE_KEY
    while [[ ${FLASH_FULL} == false ]] && [[ ${FLASH_GAIA} == false ]] && [[ ${FLASH_GECKO} == false ]]; do
        echo "Flash Mode:"
        if ! [ -z $GAIA_VALUE ] && ! [ -z $GECKO_VALUE ]; then
            echo "  1) Shallow flash Gaia/Gecko"
        fi
        if ! [ -z $GAIA_VALUE ]; then
            echo "  2) Shallow flash Gaia"
        fi
        if ! [ -z $GECKO_VALUE ]; then
            echo "  3) Shallow flash Gecko"
        fi
        if ! [ -z $IMAGE_VALUE ]; then
            echo "  4) Flash Full Image"
        fi
        read -p "What do you want to flash? [Q to exit]" FLASH_INPUT
        test ${FLASH_INPUT} == "q" || test ${FLASH_INPUT} == "Q" && echo "byebye." && exit 0
        case ${FLASH_INPUT} in
            1)  if ! [ -z $GAIA_VALUE ] && ! [ -z $GECKO_VALUE ]; then
                    FLASH_GAIA=true; FLASH_GECKO=true
                fi;;
            2)  if ! [ -z $GAIA_VALUE ]; then
                    FLASH_GAIA=true
                fi;;
            3)  if ! [ -z $GECKO_VALUE ]; then
                    FLASH_GECKO=true
                fi;;
            4)  if ! [ -z $IMAGE_VALUE ]; then
                    FLASH_FULL=true
                fi;;
        esac
    done
}

function select_flash_mode_dialog() {
    # if there are no flash flag, then ask
    if [[ ${FLASH_FULL} == false ]] && [[ ${FLASH_GAIA} == false ]] && [[ ${FLASH_GECKO} == false ]]; then
        FLASH_MODE_FLAG=""
        GAIA_KEY=DL_${TARGET_ID}${ENG_FLAG}_GAIA
        eval GAIA_VALUE=\$$GAIA_KEY
        GECKO_KEY=DL_${TARGET_ID}${ENG_FLAG}_GECKO
        eval GECKO_VALUE=\$$GECKO_KEY
        IMAGE_KEY=DL_${TARGET_ID}${ENG_FLAG}_IMG
        eval IMAGE_VALUE=\$$IMAGE_KEY
        if ! [ -z $GAIA_VALUE ] && ! [ -z $GECKO_VALUE ]; then
            COUNT=1
            FLASH_MODE_FLAG+=" $COUNT Shallow_flash_Gaia/Gecko"
        fi
        if ! [ -z $GAIA_VALUE ]; then
            COUNT=2
            FLASH_MODE_FLAG+=" $COUNT Shallow_flash_Gaia"
        fi
        if ! [ -z $GECKO_VALUE ]; then
            COUNT=3
            FLASH_MODE_FLAG+=" $COUNT Shallow_flash_Gecko"
        fi
        if ! [ -z $IMAGE_VALUE ]; then
            COUNT=4
            FLASH_MODE_FLAG+=" $COUNT Flash_Full_Image"
        fi

        dialog --backtitle "Select Build from PVT Server " --title "Flash Mode" --menu "Move using [UP] [DOWN],[Enter] to Select" \
        18 80 10 ${FLASH_MODE_FLAG} 2>${TMP_DIR}/menuitem_flash

        ret=$?
        if [ ${ret} == 1 ]; then
            echo "" && echo "byebye." && exit 0
        fi
        menuitem_flash=`cat ${TMP_DIR}/menuitem_flash`
        case $menuitem_flash in
            "") echo ""; echo "byebye."; exit 0;;
            1) FLASH_GAIA=true; FLASH_GECKO=true;;
            2) FLASH_GAIA=true;;
            3) FLASH_GECKO=true;;
            4) FLASH_FULL=true;;
        esac
    fi
}

function select_flash_mode_dialog_mac() {
    ret=$(osascript -e 'tell application "Terminal" to choose from list {"1-Flash Gaia and Gecko", "2-Flash Gaia", "3-Flash Gecko", "4-Flash Full"}')
    echo $ret
    case ${ret%%-*} in
        "") echo ""; echo "byebye."; exit 0;;
        1) FLASH_GAIA=true; FLASH_GECKO=true;;
        2) FLASH_GAIA=true;;
        3) FLASH_GECKO=true;;
        4) FLASH_FULL=true;;
    esac
    if [ -z "$ret" ]; then
        echo "" && echo "byebye." && exit 0
    fi
}

## Find the download build's info
function find_download_files_name() {
    TARGET_NAME_KEY=DL_${TARGET_ID}_NAME
    eval TARGET_NAME=\$$TARGET_NAME_KEY

    TARGET_URL_KEY=DL_${TARGET_ID}${ENG_FLAG}_URL
    eval TARGET_URL=\$$TARGET_URL_KEY

    TARGET_IMG_KEY=DL_${TARGET_ID}${ENG_FLAG}_IMG
    eval TARGET_IMG=\$$TARGET_IMG_KEY
    
    TARGET_GAIA_KEY=DL_${TARGET_ID}${ENG_FLAG}_GAIA
    eval TARGET_GAIA=\$$TARGET_GAIA_KEY

    TARGET_GECKO_KEY=DL_${TARGET_ID}${ENG_FLAG}_GECKO
    eval TARGET_GECKO=\$$TARGET_GECKO_KEY
}

## Print flash info
function print_flash_info() {
    echo    "Your Target Build: ${TARGET_NAME}"
    echo -e "URL:  ${TARGET_URL}"
    echo -e "ENG Ver: ${FLASH_ENG}"
    echo -n "Flash: "
    if [[ ${FLASH_FULL} == true ]]; then
        echo -n "Full Image."
    else
        if [[ ${FLASH_GAIA} == true ]]; then
            echo -n "Gaia, "
        fi
        if [[ ${FLASH_GECKO} == true ]]; then
            echo -n "Gecko, "
        fi
    fi
    echo ""
}

function print_flash_info_dialog() {
    create_make_sure_msg
    if [ -e ./check_versions.sh ]; then
        MAKE_SURE_MSG+="\n\n"
        MAKE_SURE_MSG+=`bash ./check_versions.sh | sed ':a;N;$!ba;s/\n/\\\n/g'`
    fi
    dialog --backtitle "Flash Information " --title "Done" --msgbox "${MAKE_SURE_MSG}" 18 80 2>${TMP_DIR}/menuitem_done
}

function download_file_from_PVT() {
    DL_URL=$1
    DL_FILE=$2
    DEST_DIR=$3
    echo ""
    echo "Download file: ${DL_URL}${DL_FILE}"
    rm -rf ${DEST_DIR}/${DL_FILE}
    run_wget -P ${DEST_DIR} ${DL_URL}${DL_FILE}
    ret=$?
    if [[ ${ret} != 0 ]]; then
        echo "Download failed." && echo "byebye." && exit 0
    fi

    # find BuildID of Latest build, then copy Latest build into their own folder.
    if [[ ${BUILD_ID} == "" ]]; then
        find_latest_build_id
        if [[ ${LATEST_BUILD_ID} != "" ]]; then
            LATEST_BUILD_ID_DIR=${DL_HOME}/${DEVICE_NAME}/${VERSION_NAME}/${DL_DIR_USR_ENG}/${LATEST_BUILD_ID}
            if [[ ! -f ${LATEST_BUILD_ID_DIR}/${DL_FILE} ]]; then
                mkdir -p ${LATEST_BUILD_ID_DIR}
                echo "Copy ${DEST_DIR}/${DL_FILE} to ${LATEST_BUILD_ID_DIR}/"
                cp ${DEST_DIR}/${DL_FILE} ${LATEST_BUILD_ID_DIR}/
            fi
        fi
    fi
}

## Shallow flash gaia/gecko
function do_shallow_flash() {
    SHALLOW_FLAG+=$ADB_FLAGS
    # flash gaia
    if [[ ${FLASH_GAIA} == true ]]; then
        if [[ ${TARGET_GAIA} == "" ]]; then
            echo "No Gaia file at ${TARGET_URL}" && exit 0
        fi
        GAIA_BASENAME=`basename ${DL_DIR}/${TARGET_GAIA}`
        # if file do not exist, latest build, or not USE_LOCAL, then download it.
        if [ ! -f ${DL_DIR}/${GAIA_BASENAME} ] || [[ ${DOWNLOAD_LATEST} == true ]] || [[ ${USE_LOCAL} != true ]]; then
            download_file_from_PVT ${TARGET_URL} ${TARGET_GAIA} ${DL_DIR}
        fi
        case `uname` in
            "Linux") SHALLOW_FLAG+=" -g${DL_DIR}/${GAIA_BASENAME}";;
            "Darwin") SHALLOW_FLAG+=" -g ${DL_DIR}/${GAIA_BASENAME}";;
        esac
    fi
    # flash gecko
    if [[ ${FLASH_GECKO} == true ]]; then
        if [[ ${TARGET_GECKO} == "" ]]; then
            echo "No Gecko file at ${TARGET_URL}" && exit 0
        fi
        GECKO_BASENAME=`basename ${DL_DIR}/${TARGET_GECKO}`
        # if file do not exist, latest build, or not USE_LOCAL, then download it.
        if [ ! -f ${DL_DIR}/${GECKO_BASENAME} ] || [[ ${DOWNLOAD_LATEST} == true ]] || [[ ${USE_LOCAL} != true ]]; then
            download_file_from_PVT ${TARGET_URL} ${TARGET_GECKO} ${DL_DIR}
        fi
        case `uname` in
            "Linux") SHALLOW_FLAG+=" -G${DL_DIR}/${GECKO_BASENAME}";;
            "Darwin") SHALLOW_FLAG+=" -G ${DL_DIR}/${GECKO_BASENAME}";;
        esac
    fi
    SHALLOW_FLAG+=" -y"
    if [ -f ./shallow_flash.sh ]; then
        echo "./shallow_flash.sh ${SHALLOW_FLAG}"
        bash ./shallow_flash.sh ${SHALLOW_FLAG}
        ret=$?
        if ! [ ${ret} == 0 ]; then
            echo "Shallow Flash failed."
            exit -1
        fi
    else
        echo -e "There is no shallow_flash.sh in your folder."
    fi
    ## if UNINSTALL_COMRIL=true, then un-install com-ril.
    if [[ ${UNINSTALL_COMRIL} == true ]]; then
        uninstall_comril
    fi
}

## Flash full image
function do_flash_image() {
    if [[ ${TARGET_IMG} == "" ]]; then
        echo "No full image file at ${TARGET_URL}" && exit 0
    fi
    IMG_BASENAME=`basename ${DL_DIR}/${TARGET_IMG}`
    # if file do not exist, latest build, or not USE_LOCAL, then download it.
    if [ ! -f ${DL_DIR}/${IMG_BASENAME} ] || [[ ${DOWNLOAD_LATEST} == true ]] || [[ ${USE_LOCAL} != true ]]; then
        download_file_from_PVT ${TARGET_URL} ${TARGET_IMG} ${DL_DIR}
    fi
    # unzip and flash
    unzip -d ${TMP_DIR} ${DL_DIR}/${IMG_BASENAME}
    CURRENT_DIR=`pwd`
    cd ${TMP_DIR}/b2g-distro/
    bash ./flash.sh -f
    ret=$?
    if ! [ ${ret} == 0 ]; then
        echo "Flash image failed."
        exit -1
    fi
    cd ${CURRENT_DIR}
}

## Find the BuildID of Latest builds.
## If there is no parameter, then this function will set TARGET_URL as SRC_URL (remove "/latest/") by default.
## $1: SRC_URL
function find_latest_build_id() {
    if [[ ${LATEST_BUILD_ID} != "" ]]; then
        echo "Latest BuildID is ${LATEST_BUILD_ID}"
        return 0
    fi
    if [[ $# == 1 ]]; then
        SRC_URL=$1
    else
        SRC_URL=${TARGET_URL%/latest/}
    fi
    SOURCE=`run_wget -qO- ${SRC_URL} | grep ">[0-9-]*/" | sed 's|.*>\([0-9-]*\)/.*|\1|' | tail -n 1`
    if [[ ${#SOURCE} -gt 13 ]]; then
        LATEST_BUILD_ID="${SOURCE//-/}"
    fi
    find_latest_build_id "${SRC_URL}/${SOURCE}"
}

#########################
# Create TEMP Folder    #
#########################
if ! which mktemp > /dev/null; then
    echo "Package \"mktemp\" not found!"
    rm -rf ./autoflashfromPVT_temp
    mkdir autoflashfromPVT_temp
    cd autoflashfromPVT_temp
    TMP_DIR=`pwd`
    cd ..
else
    TMP_DIR=`mktemp -d -t autoflashfromPVT.XXXXXXXXXXXX`
fi


#########################
# Download PVT List     #
#########################
load_list


#########################
# Processing Parameters #
#########################

## show helper if nothing specified
if [ $# = 0 ]; then echo "Nothing specified"; helper; exit 0; fi

## distinguish platform
case `uname` in
    "Linux")
        ## add getopt argument parsing
        TEMP=`getopt -o v::d::s::b::gGfwyh --long version::,device::,buildid::,usr,eng,gaia,gecko,full,help \
        -n 'invalid option' -- "$@"`

        if [ $? != 0 ]; then echo "Try '--help' for more information." >&2; exit 1; fi

        eval set -- "$TEMP";;
    "Darwin");;
esac

while true
do
    case "$1" in
        -v|--version) 
            case "$2" in
                "") version_info; exit 0; shift 2;;
                *) version $2; shift 2;;
            esac ;;
        -d|--device)
            case "$2" in
                "") device_info; exit 0; shift 2;;
                *) device $2; shift 2;;
            esac ;;
        -s)
            case "$2" in
                "") shift 2;;
                *) ADB_DEVICE=$2; ADB_FLAGS+="-s $2"; shift 2;;
            esac ;;
        -b|--buildid) BUILD_ID=$2; check_build_id; shift 2;;
        --usr) FLASH_USR_IF_POSSIBLE=true; FLASH_ENG_IF_POSSIBLE=false; shift;;
        --eng) FLASH_ENG_IF_POSSIBLE=true; FLASH_USR_IF_POSSIBLE=false; shift;;
        -f|--full) FLASH_FULL=true; shift;;
        -g|--gaia) FLASH_GAIA=true; shift;;
        -G|--gecko) FLASH_GECKO=true; shift;;
        -w) INTERACTION_WINDOW=true; shift;;
        -y) VERY_SURE=true; shift;;
        -h|--help) helper; exit 0;;
        --) shift;break;;
        "") shift;break;;
        *) helper; echo error occured; exit 1;;
    esac
done


##################################################
# For interaction GUI mode, check dialog package #
##################################################
if [[ ${INTERACTION_WINDOW} == true ]]; then
    case `uname` in
        "Linux") check_install_dialog;;
        "Darwin") ;;
    esac
fi


#############################################
# Find the B2G.${VERSION}.${DEVICE} in list #
#############################################
FOUND=false
TARGET_NAME=PVT.${VERSION_NAME}.${DEVICE_NAME}
for (( COUNT=0 ; COUNT<${DL_SIZE} ; COUNT++ ))
do
    KEY=DL_${COUNT}_NAME
    eval VALUE=\$$KEY
    
    if [ ${TARGET_NAME} == ${VALUE} ]; then
        echo "${TARGET_NAME} is found!!"
        FOUND=true
        TARGET_ID=${COUNT}
    fi
done


###########################################
# If not select DEVICE, then list DEVICES #
###########################################
if [[ ${INTERACTION_WINDOW} == true ]] && [ -z $DEVICE_NAME ]; then
    case `uname` in
        "Linux") select_device_dialog; select_version_dialog;;
        "Darwin") select_device_dialog_mac; select_version_dialog_mac;;
    esac

    if ! [ -z $TARGET_ID ]; then
        FOUND=true
    fi
fi


##########################################################################################
# If can NOT find the target from user input parameters, list the download list to user. #
##########################################################################################
if [[ ${FOUND} == false ]]; then
    echo "Can NOT found the ${TARGET_NAME}"
    echo "Please select one build from following list."
    if [[ ${INTERACTION_WINDOW} == false ]]; then
        select_build
    else
        case `uname` in
            "Linux") select_build_dialog;;
            "Darwin") select_build_dialog_mac;;
        esac
    fi
fi


#########################
# Select USER/ENG build #
#########################
ENG_FLAG=""
if_has_eng_build
if [[ ${TARGET_HAS_ENG} == true ]]; then
    if [[ ${FLASH_ENG_IF_POSSIBLE} == true ]]; then
        FLASH_ENG=true
    elif [[ ${FLASH_USR_IF_POSSIBLE} == true ]]; then
        FLASH_ENG=false
    else
        if [[ ${INTERACTION_WINDOW} == false ]]; then
            select_user_eng_build
        else
            case `uname` in
                "Linux") select_user_eng_build_dialog;;
                "Darwin") select_user_eng_build_dialog_mac;;
            esac
        fi
    fi
else
    FLASH_ENG=false
fi
if [[ ${FLASH_ENG} == true ]]; then
    ENG_FLAG="_ENG"
fi


###################################################################################
# If can NOT find the flash mode from user input parameters, list the flash mode. #
###################################################################################
if [[ ${INTERACTION_WINDOW} == false ]]; then
    select_flash_mode
else
    case `uname` in
        "Linux") select_flash_mode_dialog;;
        "Darwin") select_flash_mode_dialog_mac;;
    esac
fi


####################################
# Find the name of download files. #
####################################
find_download_files_name

if [[ ${VERSION_NAME} == "" ]] || [[ ${DEVICE_NAME} == "" ]]; then
    VER_DEV_NAME=${TARGET_NAME#PVT.*}
    VERSION_NAME=${VER_DEV_NAME%.*}
    DEVICE_NAME=${VER_DEV_NAME#*.}
fi


## TODO: print complete selection in a runnable command, in case user need to flash same option immediately


####################################################
# Create download folder, replace url for build id #
# Make sure w/ w/o dialog                          #
####################################################
if [[ ${INTERACTION_WINDOW} == false ]]; then
    prepare_download_folder
    replace_url_for_build_id
    print_flash_info
    if [[ ${VERY_SURE} == false ]]; then
        make_sure
    fi
else
    if [[ ${VERY_SURE} == false ]]; then
        # dialog function will call prepare_download_folder and replace_url_for_build_id
        case `uname` in
            "Linux") make_sure_dialog;;
            "Darwin") make_sure_dialog_mac;;
        esac
    fi
fi


##################################
# Flash full image OR gaia/gecko #
##################################
if [[ ${FLASH_FULL} == true ]]; then
    echo "Flash Full Image..."
    do_flash_image
elif [[ ${FLASH_GAIA} == true ]] || [[ ${FLASH_GECKO} == true ]]; then
    echo "Shallow Flash..."
    do_shallow_flash
fi


####################
# Version          #
####################
echo "================="
echo "Flash Information"
echo "================="
if [[ ${INTERACTION_WINDOW} == false ]]; then
    print_flash_info
    if [ -e ./check_versions.sh ]; then
        bash ./check_versions.sh
    fi
    echo "Done."
else
    case `uname` in
        "Linux") print_flash_info_dialog;;
        "Darwin") print_flash_info;;
    esac
fi


#########################
# Remove Temp Folder    #
#########################
rm -rf ${TMP_DIR}

