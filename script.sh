#/bin/bash

git clone https://github.com/tdeso/avalanche_setup
cd avalanche_setup

if [[ $USER == "root"]]; then
    bash setup.sh
    cd
    rm -rf avalanche_setup
else
    bash install.sh
fi