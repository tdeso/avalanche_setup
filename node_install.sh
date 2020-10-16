#!/bin/bash

# https://https://github.com/tdeso/avalanche_setup
# Bash script to :
# * install an Avalanche node and run it as a systemd service
# * automate its updates if desired

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    source  "${current_dir}/library.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="${HOME}/install.log"

echo '      _____               .__                       .__		  '
echo '     /  _  \___  _______  |  | _____    ____   ____ |  |__   ____   '
echo '    /  /_\  \  \/ /\__  \ |  | \__  \  /    \_/ ___\|  |  \_/ __ \  '
echo '   /    |    \   /  / __ \|  |__/ __ \|   |  \  \___|   Y  \  ___/  '
echo '   \____|__  /\_/  (____  /____(____  /___|  /\___  >___|  /\___  > '
echo '           \/           \/          \/     \/     \/     \/     \/  '

function main () {
    cd $HOME
    logTimestamp "${output_file}"

    progress installDependencies "Installing dependencies"
    progress goInstall "Installing Go"

    #textVariables
    
    progress installAvalanche "Installing Avalanche, it may take some time"

    echo 'Creating Avalanche service...'
    avalancheService >> ${output_file} 2>&1
    echo 'Creating Avalanche auto-update service...'
    monitorService >> ${output_file} 2>&1
    
    if ask "Do you wish to enable automatic updates?" Y; then
        echo 'Launching Avalanche monitoring service...'
        launchMonitor >> ${output_file} 2>&1 
        AUTO_UPDATE=yes
    fi

    echo 'Launching Avalanche node...'
    launchAvalanche >> ${output_file} 2>&1

    if [[ "${NODE_STATUS}" == "running" ]]; then
        launchedSuccesstext
        if [[ "${AUTO_UPDATE}" == "yes" ]]; then
            autoUpdatetext
        else
            updatetext
        fi
        monitortext
        nodeIDtext
    elif [[ "${NODE_STATUS}" == "exited" || "failed" ]]; then
        launchedFailedtext
        monitortext
    fi
    echo -e "Installation Log file is located at ${output_file}"
}

main