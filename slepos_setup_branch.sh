#!/bin/bash

# slepos_setup_branch.sh: Setups a SLEPOS Branch server interactively on LDAP
# Copyright (C) 2017, 2018 Geronimo Poppino

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

VERSION="1.1"

POSADMIN=/usr/sbin/posAdmin
SUDO=/usr/bin/sudo
[[ $(id -u) -eq 0 ]] && SUDO=""

#
# Configuration variables
#

COUNTRY="ar"
ORGANIZATION="myorg"

SERVER_PREFIX="srv"
STORE_PREFIX="sto"
WORKSTATION_BASENAME="CR"

ALLOW_ROLES=TRUE
ALLOW_GLOBAL_ROLES=TRUE

DHCP_DYN_LEASE_TIME=30
DHCP_FIXED_LEASE_TIME=43200

STORE_PASSWORD="mypass"

#
# Ask the user for the store information
#

echo "[ SLEPOS STORE SETUP ${VERSION} ]"
echo
echo "Please, enter the following store information:"
read -e -p "Organizational Unit (example: myOU): " OU
read -e -p "Store number: " STORE
read -e -p "Network: " NETWORK
read -e -p "Network mask: " MASK
read -e -p "Start of dynamic range of IP addresses: " DYNAMIC_IP_RANGE_START
read -e -p "End of dynamic range of IP addresses: " DYNAMIC_IP_RANGE_END
read -e -p "Start of fixed range of IP addresses: " FIXED_IP_RANGE_START
read -e -p "End of fixed range of IP addresses: " FIXED_IP_RANGE_END
read -e -p "Gateway: " GATEWAY
read -e -p "Server IP address: " SERVER_IP

function validate_posadmin_command()
{
    RET=$1
    [ $RET -eq 0 ] && echo " OK " || echo " FAILED "
    [ $RET -ne 0 ] && exit 1
}

function show_message()
{
    echo -n $@ | awk '{ printf "%-55s ", $0 }'
}

function show_config_parameters()
{
    echo
    echo "The SLEPOS store is going to be configured with the following parameters:"
    echo
    echo "* Country: ${COUNTRY}"
    echo "* Organization: ${ORGANIZATION}"
    echo "* Organizational Unit: ${OU}"
    echo "* Store number: ${STORE}"
    echo "* Store name: ${STORE_PREFIX}${STORE}"
    echo "* Network: ${NETWORK}"
    echo "* Network mask: ${MASK}"
    echo "* Dynamic IP addresses range: ${DYNAMIC_IP_RANGE_START},${DYNAMIC_IP_RANGE_END}"
    echo "* Fixed IP addresses range: ${FIXED_IP_RANGE_START},${FIXED_IP_RANGE_END}"
    echo "* Gateway: ${GATEWAY}"
    echo "* Server IP address: ${SERVER_IP}"
    echo "* Server name: ${SERVER_PREFIX}${STORE}"
    echo
    echo -n "Continue? (Y/n): "
    read confirmation

    [[ $confirmation != "Y" ]] && exit 0
}

show_config_parameters

#
# Setup Organizational Unit
#

${SUDO} ${POSADMIN} --query --list --DN ou=${OU},o=${ORGANIZATION},c=${COUNTRY} | \
    grep -w "ou=${OU},o=${ORGANIZATION},c=${COUNTRY}" 2>&1 >/dev/null
RET=$?

if [ $RET -eq 1 ];
then
    show_message "Adding organizational unit ${OU}..."
    ${SUDO} ${POSADMIN} --base o=${ORGANIZATION},c=${COUNTRY} --add --organizationalUnit --ou ${OU}
else
    show_message "Skipping adding organizational unit ${OU}. Already present..."
fi
validate_posadmin_command $?

#
# Setup store
#

show_message "Setting up store ${STORE} in ${OU}..."
${SUDO} ${POSADMIN} \
  --base ou=${OU},o=${ORGANIZATION},c=${COUNTRY} --add --scLocation --cn ${STORE_PREFIX}${STORE} \
  --ipNetworkNumber $NETWORK --ipNetmaskNumber $MASK \
  --scDhcpRange ${DYNAMIC_IP_RANGE_START},${DYNAMIC_IP_RANGE_END} \
  --scDhcpFixedRange ${FIXED_IP_RANGE_START},${FIXED_IP_RANGE_END} \
  --scDefaultGw $GATEWAY \
  --scDynamicIp TRUE --scDhcpExtern FALSE \
  --scWorkstationBaseName ${WORKSTATION_BASE_NAME} --scEnumerationMask 000 \
  --userPassword ${STORE_PASSWORD}
validate_posadmin_command $?

show_message "Setting up roles permissions..."
${SUDO} ${POSADMIN} --DN cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} --modify \
    --scLocation --scAllowRoles ${ALLOW_ROLES} --scAllowGlobalRoles ${ALLOW_GLOBAL_ROLES}
validate_posadmin_command $?

#
# Add container for branch servers
#

show_message "Adding server container..."
${SUDO} ${POSADMIN} --base cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} --add --scServerContainer --cn server
validate_posadmin_command $?

#
# Add branch server object
#
# Note: hostname must be equal to LDAP name => ${SERVER_PREFIX}${STORE}.${STORE_PREFIX}${STORE}.${OU}.${ORGANIZATION}.${COUNTRY}

show_message "Adding store server ${SERVER_PREFIX}${STORE}..."
${SUDO} ${POSADMIN} --base cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} --add --scBranchServer --cn ${SERVER_PREFIX}${STORE}
validate_posadmin_command $?

#
# Add ethernet card object
#

show_message "Adding ethernet card (eth0) object for server..."
${SUDO} ${POSADMIN} --base cn=${SERVER_PREFIX}${STORE},cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} --add --scNetworkcard \
    --scDevice eth0 --ipHostNumber ${SERVER_IP}
validate_posadmin_command $?


#
# Add services DNS, DHCP (if necessary), TFTP y posleases
#
# Note: ${SERVER_IP} is the branch server IP address

show_message "Adding DNS service..."
${SUDO} ${POSADMIN} \
    --base cn=${SERVER_PREFIX}${STORE},cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} \
    --add --scService --cn dns --ipHostNumber ${SERVER_IP} \
    --scDnsName dns --scServiceName dns --scServiceStartScript named \
    --scServiceStatus TRUE
validate_posadmin_command $?

show_message "Adding DHCP service..."
${SUDO} ${POSADMIN} \
    --base cn=${SERVER_PREFIX}${STORE},cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} \
    --add --scService --cn dhcp --ipHostNumber ${SERVER_IP} \
    --scDnsName dhcp --scServiceName dhcp \
    --scDhcpDynLeaseTime ${DHCP_DYN_LEASE_TIME} --scDhcpFixedLeaseTime ${DHCP_FIXED_LEASE_TIME} \
    --scServiceStartScript dhcpd --scServiceStatus TRUE
validate_posadmin_command $?

show_message "Adding TFTP service..."
${SUDO} ${POSADMIN} \
    --base cn=${SERVER_PREFIX}${STORE},cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} \
    --add --scService --cn tftp --ipHostNumber ${SERVER_IP} \
    --scDnsName tftp --scServiceName tftp \
    --scServiceStartScript atftpd --scServiceStatus TRUE
validate_posadmin_command $?

show_message "Adding POSLEASES service..."
${SUDO} ${POSADMIN} \
    --base cn=${SERVER_PREFIX}${STORE},cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} \
    --add --scService --cn posleases --scDnsName posleases \
    --ipHostNumber ${SERVER_IP} --scServiceName posleases \
    --scPosleasesTimeout 60 --scPosleasesChecktime 5 \
    --scPosleasesMaxNotify 6 --scServiceStartScript posleases2ldap \
    --scServiceStatus TRUE
validate_posadmin_command $?

show_message "Adding POSASWATCH service..."
${SUDO} ${POSADMIN} \
    --base cn=${SERVER_PREFIX}${STORE},cn=server,cn=${STORE_PREFIX}${STORE},ou=${OU},o=${ORGANIZATION},c=${COUNTRY} \
    --add --scService --cn posaswatch --ipHostNumber ${SERVER_IP} \
    --scDnsName posaswatch --scServiceName posASWatch \
    --scServiceStartScript posASWatch --scServiceStatus TRUE
validate_posadmin_command $?

show_message "Validating store setup..."
${SUDO} ${POSADMIN} --validate
validate_posadmin_command $?
