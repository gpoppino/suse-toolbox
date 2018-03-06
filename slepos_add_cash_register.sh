#!/bin/bash

# slepos_add_cash_register.sh: Adds a SLEPOS cash register interactively on LDAP
# Copyright (C) 2017 Geronimo Poppino

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

VERSION="1.0"
POSADMIN=/usr/sbin/posAdmin
SUDO=/usr/bin/sudo
[[ $(id -u) -eq 0 ]] && SUDO=""

# Hard disk config options
FS_TYPE=83
HD_DEVICE="/dev/sda"
HD_OBJECT_NAME="sda"

# Config file options
CONFIG_FILE_BLOCK_SIZE=1024

ADD_ROLE_FLAG=0
LEGACY_MODE_FLAG=0

function validate_command()
{
local RET=$1

    [ $RET -eq 0 ] && echo "[ OK ]" || echo "[ FAILED ]"
    [ $RET -ne 0 ] && exit 1
}

function add_role()
{
local base=$1
local object_name=$2
local role_name=$3
local role_desc=$4

    show_message "Adding role \"${role_name}\"..."
    ${SUDO} ${POSADMIN} --base $base --add --scRole --cn $object_name \
        --scRoleName "$role_name" --scRoleDescription "$role_desc"
    validate_command $?
}

function add_cash_register()
{
local base=$1
local object_name=$2
local register_name=$3
local image_dn=$4

    show_message "Adding cash register ${object_name}..."
    ${SUDO} ${POSADMIN} --base $base --add --scCashRegister \
        --cn $object_name --scCashRegisterName "$register_name" \
        --scPosImageDn $image_dn
    validate_command $?
}

function add_hard_disk()
{
local base=$1
local hd_size=$2
local swap_size=$3
local root_fs_size=$4
local home_fs_size=$5

    show_message "Adding hard disk ${HD_OBJECT_NAME}..."
    ${SUDO} ${POSADMIN} --base $base --add --scHarddisk --cn $HD_OBJECT_NAME \
        --scDevice $HD_DEVICE --scHdSize $hd_size
    validate_command $?

    show_message "Adding SWAP partition..."
    ${SUDO} ${POSADMIN} --base cn=${HD_OBJECT_NAME},$base --add --scPartition --scPartNum 0 \
        --scPartType 82 --scPartMount x --scPartSize $swap_size
    validate_command $?

    show_message "Adding / partition..."
    ${SUDO} ${POSADMIN} --base cn=${HD_OBJECT_NAME},$base --add --scPartition --scPartNum 1 \
        --scPartType $FS_TYPE --scPartMount '/' --scPartSize $root_fs_size
    validate_command $?

    if [ $home_fs_size -ne 0 ];
    then
        show_message "Adding /home partition..."
        ${SUDO} ${POSADMIN} --base cn=${HD_OBJECT_NAME},$base --add --scPartition --scPartNum 2 \
            --scPartType $FS_TYPE --scPartMount '/home' --scPartSize $home_fs_size
        validate_command $?
    fi
}

function add_configuration_file()
{
local base=$1
local object_name=$2
local destination_path=$3
local local_path=$4

    show_message "Adding configuration file ${object_name}..."
    ${SUDO} ${POSADMIN} --base $base --add --scConfigFileSyncTemplate \
        --cn $object_name --scConfigFile $destination_path --scMust TRUE \
        --scBsize $CONFIG_FILE_BLOCK_SIZE --scConfigFileLocalPath $local_path
    validate_command $?
}

function ask_for_config_file_data()
{
file_number=$1

    read -e -p "Configuration file object name: " CONF_OBJECT
    read -e -p "Configuration file destination path (file name included): " \
        DESTINATION_FILE
    read -e -p "Configuration file local path (in Admin server): " \
        LOCALPATH_FILE

    while [ ! -e $LOCALPATH_FILE ];
    do
        echo "File $LOCALPATH_FILE does not exist on localhost!"
        read -e -p "Please, reenter configuration file local path (in Admin server): " \
            LOCALPATH_FILE
    done

    CONF_OBJECT_ARRAY[$file_number]=$CONF_OBJECT
    DESTINATION_FILE_ARRAY[$file_number]=$DESTINATION_FILE
    LOCALPATH_FILE_ARRAY[$file_number]=$LOCALPATH_FILE
}

function ask_for_hd_information()
{
    read -e -p "Hard disk size (MB): " HD_SIZE
    read -e -p "Swap partition size (MB): " SWAP_SIZE
    read -e -p "Root partition size (MB): " ROOT_SIZE
    read -e -p "Home partition size (MB)(0 for no home): " HOME_SIZE
}

function request_base_information()
{
    echo "Please, enter the following cash register information:"
    read -e -p "Country: " COUNTRY
    read -e -p "Organization: " ORG
    read -e -p "Cash register object name: " OBJECT
    read -e -p "Cash register name (BIOS ID): " REGISTER_NAME
    read -e -p "Image Name (cn): " IMAGE_CN

    ask_for_hd_information
    local hd_sum=$((${SWAP_SIZE} + ${ROOT_SIZE} + ${HOME_SIZE}))
    while [ $hd_sum -gt $HD_SIZE ];
    do
        echo "WARNING: the HD size is smaller than the sum of the size of all the partitions. Please, try again:"
        ask_for_hd_information
        hd_sum=$((${SWAP_SIZE} + ${ROOT_SIZE} + ${HOME_SIZE}))
    done

    if [ ! -z "$ROLE_NAME" ] && [ $ADD_ROLE_FLAG -eq 1 ];
    then
        read -e -p "Add role short description: " ROLE_SHORT_DESC
        read -e -p "Add role long description: " ROLE_LONG_DESC
    fi
}

declare -a CONF_OBJECT_ARRAY
declare -a DESTINATION_FILE_ARRAY
declare -a LOCALPATH_FILE_ARRAY

function request_config_file_information()
{
local confirmation=true

    local i=0
    while $confirmation;
    do
        confirmation=false
        [ $i -eq 0 ] && echo -n "Add a configuration file to cash register? (y/N): "
        [ $i -ne 0 ] && echo -n "Add another configuration file to cash register? (y/N): "

        read -e conf_answer
        if [ "$conf_answer" == "y" ];
        then
            ask_for_config_file_data $((i++))
            confirmation=true
        fi
    done
}

function show_config_parameters()
{
    echo
    echo "This SLEPOS cash register is going to be added with the following parameters:"
    echo
    echo "* Country: $COUNTRY"
    echo "* Organization: $ORG"
    echo "* Cash register object name: $OBJECT"
    echo "* Cash register name (BIOS ID): $REGISTER_NAME"
    echo "* Image Name (cn): $IMAGE_CN"
    echo "* Hard disk size (MB): $HD_SIZE"
    echo "* Swap partition size (MB): $SWAP_SIZE"
    echo "* Root partition size (MB): $ROOT_SIZE"
    echo "* Home partition size (MB)(0 means disabled): $HOME_SIZE"
    if [ ! -z "$ROLE_NAME" ];
    then
        echo "* Role object name: $ROLE_NAME"
        if [ $ADD_ROLE_FLAG -ne 0 ];
        then
            echo "* Role short description: $ROLE_SHORT_DESC"
            echo "* Role long description: $ROLE_LONG_DESC"
        fi
    fi
    echo
    echo "* ${#CONF_OBJECT_ARRAY[*]} configuration files"

    local i=0
    while [ $i -lt ${#CONF_OBJECT_ARRAY[*]} ];
    do
        echo "* [$i] Configuration object name: ${CONF_OBJECT_ARRAY[$i]}"
        echo "* [$i] Configuration destination path: ${DESTINATION_FILE_ARRAY[$i]}"
        echo "* [$i] Configuration local path: ${LOCALPATH_FILE_ARRAY[$i]}"
        echo
        i=$((i + 1))
    done

    echo -n "Continue? (Y/N): "
    read confirmation
    [ "$confirmation" != "Y" ] && exit 0
}

function show_message()
{
    echo $@ | awk '{ printf "%-40s ", $0 }'
}

function usage()
{
    echo "Usage:"
    echo
    echo "To add a cash register to a new role:"
    echo " $0 -r ROLE_NAME -a"
    echo
    echo "To add a cash register to an existing role:"
    echo " $0 -r ROLE_NAME"
    echo
    echo "To add a cash register in legacy mode:"
    echo " $0 -l"
    echo
}

echo "[ SLEPOS CASH REGISTER SETUP ${VERSION} ]"
echo

function get_cli_opts()
{
    while getopts "r:ahl" OPT;
    do
        case $OPT in
            r)
                ROLE_NAME=$OPTARG
                ;;
            a)
                ADD_ROLE_FLAG=1
                ;;
            l)
                LEGACY_MODE_FLAG=1
                ;;
            h)
                usage
                exit 0
                ;;
        esac
    done
}

get_cli_opts "$@"

if [ $LEGACY_MODE_FLAG -eq 0 ] && [ $ADD_ROLE_FLAG -eq 0 ] && [ -z "$ROLE_NAME" ];
then
    usage
    exit 0
fi

if [ $ADD_ROLE_FLAG -eq 1 ] && [ -z "$ROLE_NAME" ];
then
    echo "-r option is required when using -a"
    exit 1
fi

request_base_information
request_config_file_information
show_config_parameters

BASE="cn=global,o=$ORG,c=$COUNTRY"
if [ $ADD_ROLE_FLAG -eq 1 ];
then
    add_role $BASE "$ROLE_NAME" "$ROLE_SHORT_DESC" "$ROLE_LONG_DESC"
fi

if [ ! -z "$ROLE_NAME" ];
then
    BASE="cn=${ROLE_NAME},${BASE}"
fi

add_cash_register $BASE $OBJECT "$REGISTER_NAME" cn=${IMAGE_CN},cn=default,cn=global,o=$ORG,c=$COUNTRY
add_hard_disk "cn=$OBJECT,$BASE" $HD_SIZE $SWAP_SIZE $ROOT_SIZE $HOME_SIZE

i=0
while [ $i -lt ${#CONF_OBJECT_ARRAY[*]} ];
do
    add_configuration_file "cn=$OBJECT,$BASE" "${CONF_OBJECT_ARRAY[$i]}" \
        "${DESTINATION_FILE_ARRAY[$i]}" "${LOCALPATH_FILE_ARRAY[$i]}"
    i=$((i + 1))
done

${SUDO} ${POSADMIN} --validate
