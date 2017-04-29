#!/bin/bash

# suma_create_landscape_channels.sh: Creates landscape channels as described in
# https://www.suse.com/documentation/suse-best-practices/susemanager/data/susemanager.html
#
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


#
# Make sure to review the variables at the top of this
# script and modify them accordingly.
#
# Comment the following line in order to run this script.
echo "Please, edit this script with your favourite editor." && exit 1

LANDSCAPES="DEV TEST PROD"
COMPANY="Chameleon"
ARCH="x86_64"
VERSION="12"
SP="2"
CHECKSUM="sha256"

company_lowercase=$(echo $COMPANY | tr '[:upper:]' '[:lower:]')
company_uppercase=$(echo $COMPANY | tr '[:lower:]' '[:upper:]')

PARENT_CHANNEL="$company_lowercase-sles${VERSION}-sp${SP}-pool-${ARCH}"

function channel_exists()
{
local MY_CHANNEL=$1

    spacecmd softwarechannel_list $MY_CHANNEL | grep -w $MY_CHANNEL >/dev/null
    RET=$?

    if [ $RET -eq 0 ] ;
    then
        echo "Base channel $MY_CHANNEL already exists!"
        echo "Aborting..."
        return 0
    fi

    return 1
}


function clone_base_channel_tree()
{
    spacecmd -d -- softwarechannel_clonetree -s sles${VERSION}-sp${SP}-pool-${ARCH} -p "'$company_lowercase-'"
}


function create_landscapes()
{
local PARENT_CHANNEL=$1

    for l in $LANDSCAPES;
    do
        landscape_uppercase=$(echo $l | tr '[:lower:]' '[:upper:]')
        landscape_lowercase=$(echo $l | tr '[:upper:]' '[:lower:]')

        # Create current updates channel
        spacecmd -d -- softwarechannel_create -n "'$landscape_uppercase - $company_uppercase - Current Updates - SLES${VERSION} SP${SP} ${ARCH}'" \
            -l "'$landscape_lowercase-$company_lowercase-current-updates-sles${VERSION}-sp${SP}-${ARCH}'" -c $CHECKSUM \
                -p $PARENT_CHANNEL

        # Create SUSE Manager Tools updates channel
        spacecmd -d -- softwarechannel_create -n "'$landscape_uppercase - $company_uppercase - Current Updates - SLE-Manager-Tools${VERSION} SP${SP} ${ARCH}'" \
            -l "'$landscape_lowercase-$company_lowercase-current-updates-sle-manager-tools${VERSION}-sp${SP}-${ARCH}'" -c $CHECKSUM \
                -p $PARENT_CHANNEL
    done
}

# Only legends with spaces. No special characters.
function create_channel_with_legend()
{
local LEGEND=$1
local LEGEND_LOWERCASE=$(echo $LEGEND | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
local PARENT_CHANNEL=$2

    spacecmd -d -- softwarechannel_create -n \
        "'$company_uppercase - $LEGEND - Current Updates - SLES${VERSION} SP${SP} ${ARCH}'" \
            -l "'${LEGEND_LOWERCASE}-$company_lowercase-current-updates-sles${VERSION}-sp${SP}-${ARCH}'" -c $CHECKSUM \
                -p $PARENT_CHANNEL
}

if ! channel_exists $PARENT_CHANNEL ;
then
    clone_base_channel_tree
    create_landscapes $PARENT_CHANNEL
    create_channel_with_legend "Patch Exceptions DO NOT SUBSCRIBE" $PARENT_CHANNEL
    create_channel_with_legend "Security ASAP Exceptions" $PARENT_CHANNEL
fi
