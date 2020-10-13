#!/bin/bash
# Avalanche node monitoring script
journalctl -f -u avalanche -n 0 | awk '
/You may want to update your client/ { system ("$HOME/avalanche_setup/update.sh") }'