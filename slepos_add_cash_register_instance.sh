#!/bin/bash

# slepos_add_cash_register_instance.sh: Adds a SLEPOS cash register object (instance) interactively on LDAP
# Copyright (C) 2019 Geronimo Poppino

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

POSADMIN=/usr/sbin/posAdmin

COUNTRY="PE"
O="HPSA"

function add_cash_register_object_instance()
{
local base=$1
local cn=$2
local ip_host_number="$3"
local mac_address="$4"
local ref_pc_dn="$5"
local pos_register_type="$6"
local role_based=$7
local role_dn=$8

    ROLE_OPTION=""

    [ "$role_based" == "TRUE" ] && ROLE_OPTION="--scRoleDn $role_dn"

    $POSADMIN --base ${base} --add --scWorkstation --cn $cn --ipHostNumber "$ip_host_number" --macAddress "$mac_address" --scRoleBased $role_based \
        --scRefPcDn "$ref_pc_dn" --scPosRegisterType "$pos_register_type" $ROLE_OPTION
}

function request_cash_register_instance_information()
{
    echo "Please, enter the following cash register object instance information:"
    read -e -p "Organizational Unit: " OU
    read -e -p "Store name: " STORE
    read -e -p "Cash register object name (cn): " CN
    read -e -p "IP address: " IP_ADDRESS
    read -e -p "MAC address: " MAC_ADDRESS
    read -e -p "Cash register type (BIOS ID): "  POS_REGISTER_TYPE
    read -e -p "Cash register object distinguished name (dn): " REF_PC_DN

    ROLE_DN=""
    ROLE_BASED="FALSE"
    read -e -p "Is the cash register role based? (y/N): " conf_answer
    if [ "$conf_answer" == "y" ];
    then
        read -e -p "Role distinguished name (role dn): " ROLE_DN
        ROLE_BASED="TRUE"
    fi
}

function show_config_parameters()
{
    echo
    echo "This SLEPOS cash register instance is going to be added with the following parameters:"
    echo
    echo "* Country: $COUNTRY"
    echo "* Organization: $O"
    echo "* Organizational unit: $OU"
    echo "* Store name: $STORE"
    echo "* Cash register object name to create: $CN"
    echo "* IP address : $IP_ADDRESS"
    echo "* MAC address: $MAC_ADDRESS"
    echo "* Cash register type (BIOS ID): $POS_REGISTER_TYPE"
    echo "* Cash register distinguished name: $REF_PC_DN"
    [ $ROLE_BASED = "TRUE" ] && echo "* Role distinguished name (dn):" $ROLE_DN

    read -e -p "Continue? (Y/N): " confirmation
    [ "$confirmation" != "Y" ] && exit 0
}

function validate_command()
{
local RET=$1

    [ $RET -eq 0 ] && echo "[ OK ]" || echo "[ FAILED ]"
    [ $RET -ne 0 ] && exit 1

    ${SUDO} ${POSADMIN} --validate
}

request_cash_register_instance_information
show_config_parameters

MAC_ADDRESS=$(echo $MAC_ADDRESS | tr '[a-z]' '[A-Z]')
add_cash_register_object_instance  "cn=${STORE},ou=${OU},o=${O},c=${COUNTRY}" $CN "$IP_ADDRESS" "$MAC_ADDRESS" "$REF_PC_DN" "$POS_REGISTER_TYPE" $ROLE_BASED $ROLE_DN

validate_command $?

