#!/bin/bash
#
# The quick and dirty method of installing Trident
#
#
if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

apt-get -y install postgresql nginx postfix

wget -O trident-repository.deb https://trident.li/debian/trident-repository.deb
dpkg -i trident-repository.deb
apt-get update
apt-get -y install trident

# edit /etc/trident/trident.conf
su - postgres -c "/usr/sbin/tsetup setup_db"
su - postgres -c "/usr/sbin/tsetup adduser USERNAME PASSWORD"
