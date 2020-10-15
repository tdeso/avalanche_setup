#!/bin/bash

if [[ $USER == "root" ]]; then
    apt-get -y update && apt-get -y upgrade
    apt-get install git -y
    git clone https://github.com/tdeso/avalanche_setup
    cd avalanche_setup
    bash setup.sh
    cd
    rm -rf avalanche_setup
else
    git clone https://github.com/tdeso/avalanche_setup &
    cd avalanche_setup
    sudo bash install.sh
    cd
    find $HOME/avalanche_setup ! '(' -name 'update.sh' -o -name 'monitor.sh' -o -name 'library.sh' ')' -delete 
fi
