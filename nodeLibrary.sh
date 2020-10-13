#!/bin/bash
# Node scripts Library

# Basic yes/no prompt
function confirm() {
    # call with a prompt string or use a default
   read -r -p "${1:-Are you sure? [Y/n]} " response
    case "$response" in
        [yY]*|*)
            true
            ;;
        [nN]*)
            false
            ;;
    esac
}

function importScripts() {
echo '### Importing scripts...'
cd $HOME
wget https://raw.githubusercontent.com/tdeso/node_setup/master/monitor.sh > monitor.sh
wget https://raw.githubusercontent.com/tdeso/node_setup/master/update.sh > update.sh
chmod 755 update.sh
chmod 755 monitor.sh
git clone https://github.com/jzu/bac.git 
sudo install -m 755 $HOME/bac/bac /usr/local/bin
sudo install -m 644 $HOME/bac/bac.sigs /usr/local/etc
rm -rf bac

#cd $HOME
#wget https://raw.githubusercontent.com/tdeso/node_setup/main/monitor.sh > monitor.sh
#wget https://raw.githubusercontent.com/tdeso/node_setup/main/update.sh > update.sh
#chmod 755 update.sh
#chmod 755 monitor.sh
#git clone https://github.com/jzu/bac.git
#sudo install -m 755 $HOME/bac/bac /usr/local/bin
#sudo install -m 644 $HOME/bac/bac.sigs /usr/local/etc
#rm -rf bac
#wget https://raw.githubusercontent.com/tdeso/node_setup/main/bac > bac
#sudo install -m 755 $HOME/bac /usr/local/bin
}

function goInstall () {
echo '### Installing Go...'
wget https://dl.google.com/go/go1.13.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.13.linux-amd64.tar.gz
echo "export PATH=/usr/local/go/bin:$PATH" >> $HOME/.profile
source $HOME/.profile
go version
go env -w GOPATH=$HOME/go
echo "export GOROOT=/usr/local/go" >> $HOME/.bash_profile
echo "export GOPATH=$HOME/go" >> $HOME/.bash_profile
echo "export PATH=$PATH:$GOPATH/bin:$GOROOT/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
export GOPATH=$HOME/go
}

function textVariables() {
# Setting some variables before sourcing .bash_profile
echo "export bold=\$(tput bold)" >> $HOME/.bash_profile
echo "export underline=\$(tput smul)" >> $HOME/.bash_profile
echo "export normal=\$(tput sgr0)" >> $HOME/.bash_profile
# end of variables
source $HOME/.bash_profile
}

function installAvalanche() {
echo 'Cloning avalanchego directory...'
cd $HOME/
go get -v -d github.com/ava-labs/avalanchego/...

echo 'Building avalanchego binary...'
cd $GOPATH/src/github.com/ava-labs/avalanchego
./scripts/build.sh

echo 'Creating Avalanche node service...'

PUBLIC_IP=$(ip route get 8.8.8.8 | sudo sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
sudo bash -c 'cat <<EOF > /etc/.avalanche.conf
ARG1=--public-ip='$PUBLIC_IP'
ARG2=--snow-quorum-size=14
ARG3=--snow-virtuous-commit-threshold=15
EOF'

sudo USER='$USER' bash -c 'cat <<EOF > /etc/systemd/system/avalanche.service
[Unit]
Description=Avalanche node service
After=network.target
[Service]
User='$USER'
Group='$USER'
WorkingDirectory='$GOPATH'/src/github.com/ava-labs/avalanchego
EnvironmentFile=/etc/.avalanche.conf
ExecStart='$GOPATH'/src/github.com/ava-labs/avalanchego/build/avalanchego \$ARG1 \$ARG2 \$ARG3
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF'
}

function writemonitor () {
echo 'Creating Avalanche auto-update service'
sudo USER='$USER' bash -c 'cat <<EOF > /etc/systemd/system/monitor.service
[Unit]
Description=Avalanche monitoring service
After=network.target
[Service]
User='$USER'
Group='$USER'
WorkingDirectory='$HOME'
ExecStart=/bin/bash '$HOME'/monitor.sh
StandardInput=journal+console
StandardOutput=journal+console
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF'
}

function launchMonitor () {
  echo 'Launching Avalanche monitoring service...'
  sudo systemctl enable monitor
  sudo systemctl start monitor    
}

function node_ID() {
  bac -f info.getNodeID | grep NodeID | awk 'NR==1 {print $2}' | tr -d \"  
}
function node_status () {
  systemctl -a list-units | grep -F 'avalanche' | awk 'NR ==1 {print $4}' | tr -d \"
}

function launchAvalanche() {
  echo '### Launching Avalanche node...'
  sudo systemctl enable avalanche
  sudo systemctl start avalanche
  NODE_ID=$(eval node_ID)
  NODE_STATUS=$(eval node_status)
}

function launchedtext() {
  echo "${bold}##### AVALANCHE NODE SUCCESSFULLY LAUNCHED #####${normal}"
  echo ''
  echo "${bold}Your NodeID is:${normal}"
  echo "${NODE_ID}"
  echo 'Use it to add your node as a validator by following the instructions at:'
  echo "${underline}https://docs.avax.network/v1.0/en/tutorials/adding-validators/#add-a-validator-with-the-wallet${normal}"
  echo ''
}

function launchedFailedtext() {
  echo "${bold}##### AVALANCHE NODE LAUNCH FAILED #####${normal}"
}

function autoUpdatetext() {
  echo 'To disable automatic updates, type the following command:'
  echo '    sudo systemctl stop monitor'
  echo 'To check the node monitoring service status, type the following command:'
  echo '    sudo systemctl status monitor'
  echo 'To check its logs, type the following command:'
  echo '    journalctl -u monitor'
}

function updatetext() {
  echo "To update your node, run the update.sh script located at $HOME by using the following command:"
  echo "    cd $HOME && ./update.sh"
  echo 'To enable automatic updates, type the following command:'
  echo '    sudo systemctl enable && sudo systemctl start monitor'
}

function monitortext () {
  echo ''
  echo 'To monitor the Avalanche node service, type the following commands:'
  echo '    sudo systemctl status avalanche'
  echo '    journalctl -u avalanche'
  echo 'To change the node launch arguments, edit the following file:'
  echo '    /etc/.avalanche.conf'
  echo 'To monitor the node monitoring service, type the following commands:'
  echo '    sudo systemctl status monitor'
  echo '    journalctl -u monitor'
  echo ''
}