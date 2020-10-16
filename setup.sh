#!/bin/bash

# Bash script that automates setting up an Avalanche node on a Ubuntu 18.04.X server
# For more information, see: https://https://github.com/tdeso/avalanche_setup

if [[ $USER == "root" ]]; then
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install git
    cd ~
    git clone https://github.com/tdeso/avalanche_setup.git
    bash ~/avalanche_setup/node_setup.sh
    rm -rf ~/avalanche_setup
    else
    git clone https://github.com/tdeso/avalanche_setup.git
    sudo bash ~/avalanche_setup/node_install.sh
    cd $HOME/avalanche_setup/
    find . ! '(' -name 'update.sh' -o -name 'monitor.sh' -o -name 'library.sh' ')' -exec rm -rf {} +
    cd ~
    rm -rf go1.13.linux-amd64.tar.gz
fi