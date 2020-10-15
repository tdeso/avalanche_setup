#!/bin/bash

if [[ $USER == "root" ]]; then
    apt-get -y update;
    apt-get -y install git ;
    cd ~;
    sleep 1;
    git clone https://github.com/tdeso/avalanche_setup.git;
    sleep 1;
    bash -c ~/avalanche_setup/setup.sh;
    sleep 1;
    rm -rf ~/avalanche_setup

else
    git clone https://github.com/tdeso/avalanche_setup.git;
    cd avalanche_setup;
    sudo bash install.sh;
    cd;
    rm -rf go1.13.linux-amd64.tar.gz;
    find -path $HOME/avalanche_setup/ ! '(' -name 'update.sh' -o -name 'monitor.sh' -o -name 'library.sh' ')' -exec rm -rf {} + 
fi