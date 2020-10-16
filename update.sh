#!/usr/bin/env bash

# https://https://github.com/tdeso/avalanche_setup
# Bash script to update an Avalanche node that runs as a service named avalanche

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    source "${current_dir}/library.sh"
    source "${HOME}/.bash_profile"
}

function node_version () {
  bac info.getNodeVersion | egrep -o 'avalanche.*"}' | sed 's/avalanche//' | tr -d '\/"}'
}

function monitorStatus () {
  systemctl -a list-units | grep -F 'monitor' | awk 'NR ==1 {print $4}' | tr -d \"
}

function updateAvalanche() {
  sudo systemctl stop avalanche
  cd ${GOPATH}/src/github.com/ava-labs/avalanchego
  git pull
  ./scripts/build.sh
  sudo systemctl start avalanche 
  if [[ "${MONITOR_STATUS}" == "running" ]]; then    
  sudo systemctl restart monitor    
  fi
  NODE_STATUS=$(eval node_status)
  while [[ -z $NODE_VERSION2 ]]; do
      sleep 0.2
      NODE_VERSION2=$(eval node_version)
  done
}

function updateSuccesstext() {
  echo "##### AVALANCHE NODE SUCCESSFULLY UPDATED TO" ${NODE_VERSION2}  
}

function updateFailedtext() {
  echo "##### AVALANCHE NODE UPDATE FAILED"    
}

function main () {
    echo '      _____               .__                       .__		          '
    echo '     /  _  \___  _______  |  | _____    ____   ____ |  |__   ____   '
    echo '    /  /_\  \  \/ /\__  \ |  | \__  \  /    \_/ ___\|  |  \_/ __ \  '
    echo '   /    |    \   /  / __ \|  |__/ __ \|   |  \  \___|   Y  \  ___/  '
    echo '   \____|__  /\_/  (____  /____(____  /___|  /\___  >___|  /\___  > '
    echo '           \/           \/          \/     \/     \/     \/     \/  '

    progress updateAvalanche "Updating Avalanche"

    if [[ "${NODE_STATUS}" == "running" ]] && [[ "${NODE_VERSION1}" != "${NODE_VERSION2}" ]]; then
        updateSuccesstext
    elif [[ "${NODE_STATUS}" == "running" ]] && [[ "${NODE_VERSION1}" == "${NODE_VERSION2}" ]]; then
        updateFailedtext
    elif [[ "${NODE_STATUS}" == "exited" ]] || [[ "${NODE_STATUS}" == "failed" ]]; then
        launchedFailedtext
    fi
    monitortext
    if [[ "${MONITOR_STATUS}" == "running" ]]; then    
      echo 'To monitor the node updating service, type the following commands:'
      echo '    sudo systemctl status monitor'
      echo '    journalctl -u monitor'
      echo ''   
    fi
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="${HOME}/"$(date +%FT%T)".log"
NODE_VERSION1=$(eval node_version)
MONITOR_STATUS=$(eval monitorStatus)
logTimestamp "${output_file}"
main 2>> ${output_file}