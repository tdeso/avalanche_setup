# Bash scripts to setup a Ubuntu VPS server and run an Avalanche node

This is a setup script to automate the setup of a Ubuntu VPS and install an Avalanche node. It does the following:
* Adds a new user account with sudo access
* Adds a public ssh key for the new user account
* Disables password authentication to the server
* Deny root login to the server
* Setup Uncomplicated Firewall
* Create Swap file based on machine's installed memory
* Setup the timezone for the server (Default to "Asia/Singapore")
* Install Network Time Protocol
* Installs AvalancheGo
* Setup automatic updates for AvalancheGo

All you'll have to do to start validating once the script is done is save the NodeID and follow the instructions at:  
https://docs.avax.network/v1.0/en/tutorials/adding-validators/#add-a-validator-with-the-wallet

# Requirements

A VPS with:
* Hardware: 2 GHz or faster CPU, >=4 GB RAM, >=2 GB hard disk.
* OS: Ubuntu >= 18.04

# Usage
If you're on Windows, open a Powershell window, if you're on macOS or Linux, open a Terminal window and execute the following commands:  

Generate an ssh key on your local machine:
```bash
ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub
```

SSH into your server: 
```bash
ssh root@10.10.10.10
# Replace 10.10.10.10 by your VPS public IP address
```

Run the setup script by using this command:
```bash
bash <(curl -fsSl https://raw.githubusercontent.com/tdeso/avalanche_setup/main/test.sh)
```

Once done, reboot and SSH into your server using the user you just created:
```bash
ssh [user]@10.10.10.10 -p [ssh_port]
# Replace user by the username you just created 
# Use -p with the SSH port number you chose if you changed it, otherwise don't use that option.
```

Run the installation script
```bash
git clone https://github.com/tdeso/avalanche_setup.git && cd avalanche_setup && bash install.sh
```

Save the NodeID and follow the instructions at:  
https://docs.avax.network/v1.0/en/tutorials/adding-validators/#add-a-validator-with-the-wallet

Backup your staking key to a local folder using the command in a local terminal:
```bash
scp -r -P [PORT] user@[XX.XX.XX.XX]:$HOME/go/src/github.com/ava-labs/.avalanchego/staking/ Path/to/local/folder
# Use the -P [PORT] option if you changed the SSH port.
```

# Setup prompts
You will be prompted to enter several things:

* When the setup script is run, you will be prompted to enter the username and password of the new user account. 

* Following that, you will then be prompted to add a public ssh key (which should be from your local machine) for the new account. To generate an ssh key from your local machine:
```bash
ssh-keygen -t rsa
cat ~/.ssh/id_rsa.pub
```
* You will then be asked if you want to change the SSH port and specify which one you want if you answered yes.

* You will then be prompted to specify a [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for the server. It will be set to 'America/New_York' if you do not specify a value.

* You will be asked if you want to enable automatic node updates.

# Credits
This uses a slighlty modified version of a VPS setup script taken from [ubuntu-server-setup]https://github.com/jasonheecs/ubuntu-server-setup.
This is inspired from [ablock.io](https://github.com/ablockio/AVAX-node-installer) script, with multiple additions and modifications.  
It installs and uses [basic avalanche cli](https://github.com/jzu/bac), which is Unix CLI wrapper around the Avalanche JSON API that makes issuing simple calls easier.

# Licence
[MIT](https://choosealicense.com/licenses/mit/)
