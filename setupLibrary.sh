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

function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

function changeport() {
    read -r -p "What port do you wish to use ? Do not chose the ports 9650 or 9651 : " ssh_port
    sudo sed -re "s/^(\#?)(Port)([[:space:]]+)(.*)/Port "${ssh_port}"/" -i /etc/ssh/sshd_config
}