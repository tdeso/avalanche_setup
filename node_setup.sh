#!/bin/bash

set -e

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    source "${current_dir}/library.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"

function main() {
    read -rp "Enter the username of the new user account: " username

    disablePasswdEntropy
    promptForPassword

    # Run setup functions
    trap cleanup EXIT SIGHUP SIGINT SIGTERM

    # Remove already existing users
    ls /home/ | deluser --remove-home
    addUserAccount "${username}" "${password}" true

    read -rp $'Paste in the public SSH key for the new user:\n' sshKey

    if ask "Do you wish to change the SSH port ?" N; then
        changePort
    fi
    
    if ask "Do you wish to change the root password?" N; then
        promptForRootPassword
        echo "${rootpassword}:${rootpassword}" | passwd root

    fi

    echo 'Running setup script...'
    logTimestamp "${output_file}"

    exec 3>&1 >>"${output_file}" 2>&1
    disableSudoPassword "${username}"
    addSSHKey "${username}" "${sshKey}"
    changeSSHConfig
    setupUfw

    if ! hasSwap; then
        setupSwap
    fi

    setupTimezone

    echo "Installing Network Time Protocol... " >&3
    configureNTP

    sudo service ssh restart
    
    rm -rf /var/log/journal/ 
    sudo sed -re 's/^(\#?)(Storage)(=)(.*)/Storage=persistent/' -i /etc/systemd/journald.conf

    PUBLIC_IP=$(ip route get 8.8.8.8 | sudo sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')

    cleanup
    cleanupEntropy >&3

    if [[ "${ssh_port}" == 22 ]]; then
        ssh_command="ssh ${username}@${PUBLIC_IP}"
    else
        ssh_command="ssh ${username}@${PUBLIC_IP} -p ${ssh_port}"
    fi        
    echo -e "Setup Done! Log file is located at ${output_file} \nNow please reboot and connect as ${username} using the command:\n${ssh_command}" >&3
}

function setupSwap() {
    createSwap
    mountSwap
    tweakSwapSettings "10" "50"
    saveSwapSettings "10" "50"
}

function hasSwap() {
    [[ "$(sudo swapon -s)" == *"/swapfile"* ]]
}

function setupTimezone() {
    echo -ne "Enter the timezone for the server (Default is 'Asia/Singapore'):\n" >&3
    read -r timezone
    if [ -z "${timezone}" ]; then
        timezone="Asia/Singapore"
    fi
    setTimezone "${timezone}"
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}

# Keep prompting for the password and password confirmation
function promptForPassword() {
   PASSWORDS_MATCH=0
   while [ "${PASSWORDS_MATCH}" -eq "0" ]; do
       read -s -rp "Enter new UNIX password:" password
       printf "\n"
       read -s -rp "Retype new UNIX password:" password_confirmation
       printf "\n"

       if [[ "${password}" != "${password_confirmation}" ]]; then
           echo "Passwords do not match! Please try again."
       else
           PASSWORDS_MATCH=1
       fi
   done 
}

function promptForRootPassword() {
   ROOT_PASSWORDS_MATCH=0
   while [ "${ROOT_PASSWORDS_MATCH}" -eq "0" ]; do
       read -s -rp "Enter new root password:" rootpassword
       printf "\n"
       read -s -rp "Retype new root password:" rootpassword_confirmation
       printf "\n"

       if [[ "${rootpassword}" != "${rootpassword_confirmation}" ]]; then
           echo "Passwords do not match! Please try again."
       else
           ROOT_PASSWORDS_MATCH=1
       fi
   done 
}

main