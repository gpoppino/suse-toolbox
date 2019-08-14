#!/bin/bash

# ses_zap_disks.sh: Zaps disks on a Linux systems
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

# Disks to exclude from zapping/wipping
# The syntax is: disk1|disk2|disk3|disk4
#
EXCLUDE_DISKS="sda|sdb"

function wipe_disk()
{
DISK=$1

    echo
    echo "* Wiping disk: /dev/${DISK}"
    # Wipe the beginning of each partition
    for partition in /dev/${DISK}{1..63}
    do
      [ -b $partition ] && dd if=/dev/zero of=$partition bs=4096 count=1 oflag=direct
    done

    # Wipe the beginning of the drive
    dd if=/dev/zero of=/dev/${DISK} bs=512 count=34 oflag=direct

    # Wipe backup partition tables
    size=`blockdev --getsz /dev/${DISK}`
    position=$((size - 33))
    dd if=/dev/zero of=/dev/${DISK} bs=512 count=33 seek=$position oflag=direct
}

function build_disks_list()
{
    DISKS=$(lsblk -l -o name,type -x type | grep -w disk | cut -f1 -d' ' | \
        egrep -v $EXCLUDE_DISKS)
    echo $DISKS
}

function wipe_remaining_disks()
{
    for disk in $(build_disks_list);
    do
        wipe_disk $disk
    done
}

function show_selection_of_disks()
{
    DISKS=$(build_disks_list)
    if [ -z "${DISKS}" ];
    then
        echo "No disks to wipe."
        echo "Please, check the EXCLUDE_DISKS variable in the header of this script."
        exit 0
    fi

    echo "These disks will be wiped (ALL DATA WILL BE LOST):"
    echo $DISKS
    echo
    echo "These disks will NOT be wiped (will remain untouched):"
    echo $EXCLUDE_DISKS | tr '|' ' '
    echo
}

show_selection_of_disks

echo "Proceed? (n/Y):"
read -e answer
[ $answer != 'Y' ] && exit 0

wipe_remaining_disks
