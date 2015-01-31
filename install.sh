#!/bin/bash

set -e

# make sure only root can run this script
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root. Try to run with \"sudo\" command." 1>&2
   exit 1
fi

source ./config.ini
export INSTALL_LOG=~/install.log

echo "* Start update and upgarde ..." | tee -a ${INSTALL_LOG}
sudo apt-get -yq update
sudo apt-get -yq upgrade
sudo apt-get -yq install build-essential
echo "* Update and upgarde finished." | tee -a ${INSTALL_LOG}

bash ./lamp.sh 2>&1 | tee -a ${INSTALL_LOG}