#!/bin/bash

# Avalanche node auto-updating script
# https://https://github.com/tdeso/avalanche_setup

journalctl -f -u avalanche -n 0 | awk '
/You may want to update your client/ { system ("$HOME/avalanche_setup/update.sh") }'