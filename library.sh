#!/bin/bash

# https://https://github.com/tdeso/avalanche_setup
# Library script

# yes/no prompt
function ask() {
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

# Add the new user account
# Arguments:
#   Account Username
#   Account Password
#   Flag to determine if user account is added silently. (With / Without GECOS prompt)
function addUserAccount() {
    local username=${1}
    local password=${2}
    local silent_mode=${3}

    if [[ ${silent_mode} == "true" ]]; then
        sudo adduser --disabled-password --gecos '' "${username}"
    else
        sudo adduser --disabled-password "${username}"
    fi

    echo "${username}:${password}" | sudo chpasswd
    sudo usermod -aG sudo "${username}"
    adduser "${username}" systemd-journal
}

# Add the local machine public SSH Key for the new user account
# Arguments:
#   Account Username
#   Public SSH Key
function addSSHKey() {
    local username=${1}
    local sshKey=${2}

    execAsUser "${username}" "mkdir -p ~/.ssh; chmod 700 ~/.ssh; touch ~/.ssh/authorized_keys"
    execAsUser "${username}" "echo \"${sshKey}\" | sudo tee -a ~/.ssh/authorized_keys"
    execAsUser "${username}" "chmod 600 ~/.ssh/authorized_keys"
}

# Execute a command as a certain user
# Arguments:
#   Account Username
#   Command to be executed
function execAsUser() {
    local username=${1}
    local exec_command=${2}

    sudo -u "${username}" -H bash -c "${exec_command}"
}

# Modify the sshd_config file
# shellcheck disable=2116
function changeSSHConfig() {       
    sudo sed -re 's/^(\#?)(PasswordAuthentication)([[:space:]]+)yes/\2\3no/' -i."$(echo 'old')" /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(PermitRootLogin)([[:space:]]+)(.*)/PermitRootLogin no/' -i /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(RSAAuthentication)([[:space:]]+)(.*)/RSAAuthentication no/' -i /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(UsePAM)([[:space:]]+)(.*)/UsePAM no/' -i /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(KerberosAuthentication)([[:space:]]+)(.*)/KerberosAuthentication no/' -i /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(GSSAPIAuthentication)([[:space:]]+)(.*)/GSSAPIAuthentication no/' -i /etc/ssh/sshd_config
}

# Setup the Uncomplicated Firewall
function setupUfw() {
    ssh_port=$(cat /etc/ssh/sshd_config | grep Port[[:space:]] | awk 'NR==1 {print $2}' | tr -d \")
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow "${ssh_port}"
    sudo ufw allow 9650
    sudo ufw allow 9651
    yes y | sudo ufw enable
}

# Create the swap file based on amount of physical memory on machine (Maximum size of swap is 4GB)
function createSwap() {
   local swapmem=$(($(getPhysicalMemory) * 2))

   # Anything over 4GB in swap is probably unnecessary as a RAM fallback
   if [ ${swapmem} -gt 4 ]; then
        swapmem=4
   fi

   sudo fallocate -l "${swapmem}G" /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
}

# Mount the swapfile
function mountSwap() {
    sudo cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
}

# Modify the swapfile settings
# Arguments:
#   new vm.swappiness value
#   new vm.vfs_cache_pressure value
function tweakSwapSettings() {
    local swappiness=${1}
    local vfs_cache_pressure=${2}

    sudo sysctl vm.swappiness="${swappiness}"
    sudo sysctl vm.vfs_cache_pressure="${vfs_cache_pressure}"
}

# Save the modified swap settings
# Arguments:
#   new vm.swappiness value
#   new vm.vfs_cache_pressure value
function saveSwapSettings() {
    local swappiness=${1}
    local vfs_cache_pressure=${2}

    echo "vm.swappiness=${swappiness}" | sudo tee -a /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=${vfs_cache_pressure}" | sudo tee -a /etc/sysctl.conf
}

# Set the machine's timezone
# Arguments:
#   tz data timezone
function setTimezone() {
    local timezone=${1}
    echo "${1}" | sudo tee /etc/timezone
    sudo ln -fs "/usr/share/zoneinfo/${timezone}" /etc/localtime # https://bugs.launchpad.net/ubuntu/+source/tzdata/+bug/1554806
    sudo dpkg-reconfigure -f noninteractive tzdata
}

# Configure Network Time Protocol
function configureNTP() {
    ubuntu_version="$(lsb_release -sr)"

    if [[ $ubuntu_version == '20.04' ]]; then
        sudo systemctl restart systemd-timesyncd
    else
        sudo apt-get update
        sudo apt-get --assume-yes install ntp
    fi
}

# Gets the amount of physical memory in GB (rounded up) installed on the machine
function getPhysicalMemory() {
    local phymem
    phymem="$(free -g|awk '/^Mem:/{print $2}')"
    
    if [[ ${phymem} == '0' ]]; then
        echo 1
    else
        echo "${phymem}"
    fi
}

# Disables password entropy settings
function disablePasswdEntropy() {
    sudo cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
    sudo sed -re 's/(pam_unix.so)(.*)/pam_unix.so minlen=1 sha512/g' -i /etc/pam.d/common-password
    sed 's/^[^#]*pam_cracklib/#&/' -i /etc/pam.d/common-password
}


function revertPasswdEntropy() {
    sudo cp /etc/pam.d/common-password.bak /etc/pam.d/common-password
    sudo rm -rf /etc/pam.d/common-password.bak
}

# Revert password entropy changes if a backup exists
function cleanupEntropy() {
    if [[ -f "/etc/pam.d/common-password.bak" ]]; then
        revertPasswdEntropy
    fi
}

# Disables the sudo password prompt for a user account by editing /etc/sudoers
# Arguments:
#   Account username
function disableSudoPassword() {
    local username="${1}"

    sudo cp /etc/sudoers /etc/sudoers.bak
    sudo bash -c "echo '${1} ALL=(ALL) NOPASSWD: ALL' | (EDITOR='tee -a' visudo)"
}

# Reverts the original /etc/sudoers file before this script is ran
function revertSudoers() {
    sudo cp /etc/sudoers.bak /etc/sudoers
    sudo rm -rf /etc/sudoers.bak
}

# Revert sudoers changes if a backup exists
function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

# Prompt for new SSH port and change it
function changePort() {
    read -r -p "What port do you wish to use ? Do not chose the ports 9650 or 9651 : " ssh_port
    sudo sed -re "s/^(\#?)(Port)([[:space:]]+)(.*)/Port "${ssh_port}"/" -i /etc/ssh/sshd_config
}

function logTimestamp() {
    local filename=${1}
    {
        echo "===================" 
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}

##################################################
#-------------------------------------------------
#------------- Node related functions ------------

function installDependencies() {
  echo 'Updating packages...' #>&3
  sudo apt-get update -y
  sudo apt-get install -y jq perl w3m
  sudo apt-get -y install gcc g++ make

# Set permissions and install basic avalanche cli
#function importScripts() {

  sudo chmod 500 ${current_dir}/update.sh
  sudo chmod 500 ${current_dir}/monitor.sh
  sudo chmod 400 ${current_dir}/library.sh
  cd $HOME
  git clone https://github.com/jzu/bac.git 
  sudo install -m 755 $HOME/bac/bac /usr/local/bin
  sudo install -m 644 $HOME/bac/bac.sigs /usr/local/etc
  rm -rf bac
}

# Install go and setup $GOPATH
function goInstall () {
  cd $HOME  
  wget https://dl.google.com/go/go1.13.linux-amd64.tar.gz
  sudo tar -C /usr/local -xzf go1.13.linux-amd64.tar.gz
  echo "export PATH=/usr/local/go/bin:$PATH" >> $HOME/.profile
  source $HOME/.profile
  go version
  #go env -w GOPATH=$HOME/go
  #echo "export GOROOT=/usr/local/go" >> $HOME/.bashrc
  #echo "export GOPATH=$HOME/go" >> $HOME/.bashrc
  #echo "export PATH=$PATH:$GOPATH/bin:$GOROOT/bin:" >> $HOME/.bashrc
  #source $HOME/.bashrc
  #export GOPATH=$HOME/go
}

# Set some variables for prettier output in terminal
function textVariables() {
  # Setting some variables before sourcing .bashrc
  echo "export GOROOT=/usr/local/go" >> $HOME/.bashrc
  echo "export GOPATH=$HOME/go" >> $HOME/.bashrc
  echo "export PATH=$PATH:\$GOPATH/bin:\$GOROOT/bin" >> $HOME/.bashrc  
  echo "export bold=\$(tput bold)" >> $HOME/.bashrc
  echo "export underline=\$(tput smul)" >> $HOME/.bashrc
  echo "export normal=\$(tput sgr0)" >> $HOME/.bashrc
  source $HOME/.bashrc
  go env -w GOPATH=$HOME/go
  export GOPATH=$HOME/go
  
}

# Install Avalanche from source:
# Clone the avalanchego repo
# Build the binary
function installAvalanche() {
  cd $HOME/
  go get -v -d github.com/ava-labs/avalanchego/...
  cd $GOPATH/src/github.com/ava-labs/avalanchego
  ./scripts/build.sh
}

# Create a systemd service to run avalanchego with auto restart settings and launch arguments
function avalancheService() {
    echo 'Creating Avalanche node service...'
PUBLIC_IP=$(ip route get 8.8.8.8 | sudo sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
sudo mkdir -p /etc/systemd/system/avalanche.service.d/
{ echo "[Service]";
  echo "Environment="ARG1=--public-ip=$PUBLIC_IP"";
  echo "Environment="ARG2=--snow-quorum-size=14"";
  echo "Environment="ARG3=--snow-virtuous-commit-threshold=15""
} | sudo tee /etc/systemd/system/avalanche.service.d/launch_arguments.conf

sudo USER='$USER' bash -c 'cat <<EOF > /etc/systemd/system/avalanche.service
[Unit]
Description=Avalanche node service
After=network.target
[Service]
User='$USER'
Group='$USER'
WorkingDirectory='$GOPATH'/src/github.com/ava-labs/avalanchego
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

# Create a systemd service that runs monitor.sh script
# monitor.sh reads the log and launches the update.sh script 
# when a string signaling a new avalanchego client is available
function monitorService () {
sudo USER='$USER' bash -c 'cat <<EOF > /etc/systemd/system/monitor.service
[Unit]
Description=Avalanche updating service
After=network.target
[Service]
User='$USER'
Group='$USER'
WorkingDirectory='$HOME'
ExecStart=+/bin/bash '$HOME'/avalanche_setup/monitor.sh
TimeoutStopSec=60s
TimeoutStartSec=10s
[Install]
WantedBy=multi-user.target
EOF'
}

# Launch monitor service
function launchMonitor () {
  sudo systemctl enable monitor
  sudo systemctl start monitor    
}

# Get Avalanche NodeID
function node_ID() {
  bac info.getNodeID | egrep -o 'NodeID.*"}' | tr -d \"\}  
}

# Get avalanche service status
function node_status () {
  systemctl -a list-units | grep -F 'avalanche' | awk 'NR ==1 {print $4}' | tr -d \"
}

# Launch avalanche service
function launchAvalanche() {
  sudo systemctl enable avalanche
  sudo systemctl start avalanche
  NODE_STATUS=$(eval node_status)
  if [[ "${NODE_STATUS}" == "running" ]]; then
    while [[ -z $NODE_ID ]]; do
        sleep 0.2
        NODE_ID=$(eval node_ID)
    done 
  fi
}

# Texts about node monitoring
function launchedSuccesstext() {
  echo ''
  echo "${bold}##### AVALANCHE NODE SUCCESSFULLY LAUNCHED${normal}"
}

function nodeIDtext() {
  echo ''
  echo "${bold}Your NodeID is:" ${NODE_ID} ${normal}
  echo ''
  echo 'Use it to add your node as a validator by following the instructions at:'
  echo "${underline}https://docs.avax.network/v1.0/en/tutorials/adding-validators/#add-a-validator-with-the-wallet${normal}"
  echo ''
}

function launchedFailedtext() {
  echo ''
  echo "${bold}##### AVALANCHE NODE LAUNCH FAILED${normal}"
}

function autoUpdatetext() {
  echo ''
  echo 'To disable automatic updates, type the following command:'
  echo '    sudo systemctl stop monitor'
  echo 'To check the node updating service status, type the following command:'
  echo '    sudo systemctl status monitor'
  echo 'To check its logs, type the following command:'
  echo '    journalctl -u monitor'
}

function updatetext() {
  echo ''
  echo "To update your node, run the update.sh script located at $HOME by using the following command:"
  echo "    cd $HOME/avalanche_setup && ./update.sh"
  echo 'To enable automatic updates, type the following command:'
  echo '    sudo systemctl enable monitor && sudo systemctl start monitor'
}

function monitortext () {
  echo ''
  echo 'To monitor the Avalanche node service, type the following commands:'
  echo '    sudo systemctl status avalanche'
  echo '    journalctl -u avalanche'
  echo 'To change the node launch arguments, edit the following file:'
  echo '    /etc/systemd/system/avalanche.service.d/launch_arguments.conf'
}

# Display an animation while process executes in background.
# About trap command:
# >Look for the 4 common signals that indicate this script was killed.
# >If the background command was started, kill it, too.
function progress() {
    local command=${1}
    local string=${2}

    string1="${string}·.. "
    string2="${string}.·. "
    string3="${string}..·"
    trap "kill ${!} 2>/dev/null; exit 3" SIGHUP SIGINT SIGQUIT SIGTERM
    ${command} >> ${output_file} 2>&1 & # execute command in the background.
    # The /proc directory exists while the command runs.
    while [ -e /proc/$! ]; do
        {
        echo -ne "${string1}\r"
        sleep 0.75
        echo -ne "${string2}\r"
        sleep 0.75
        echo -ne "${string3}\r"
        sleep 0.75
        }
    done
    echo "${string}..."
}

#    if [[ -f "$HOME/.bashrc" ]]; then
#        source $HOME/.bashrc >> ${output_file} 2>&1 &
#    fi
