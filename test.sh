#!/bin/bash

if [[ $USER == "root" ]]; then
    apt-get -y update;
    apt-get -y upgrade;
    apt-get -y install git ;
    cd ~;
    git clone https://github.com/tdeso/avalanche_setup.git;
    bash ~/avalanche_setup/setup.sh;
    rm -rf ~/avalanche_setup

else
    git clone https://github.com/tdeso/avalanche_setup.git;
    cd avalanche_setup;
    sudo bash install.sh;
    cd;
    rm -rf go1.13.linux-amd64.tar.gz;
    find -path $HOME/avalanche_setup/ ! '(' -name 'update.sh' -o -name 'monitor.sh' -o -name 'library.sh' ')' -exec rm -rf {} + 
fi