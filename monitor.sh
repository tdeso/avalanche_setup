#!/bin/bash
# Avalanche node monitoring script
function nosudopasswd() {
    local username="${1}"
    sudo bash -c "echo '${1} ALL=(ALL) NOPASSWD: ${HOME}/update.sh' | (EDITOR='tee -a' visudo)"
}

journalctl -f -u avalanche -n 0 | awk '
/You may want to update your client/ { system ("$HOME/update.sh") }'