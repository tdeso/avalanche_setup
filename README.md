# Bash scripts to setup a Ubuntu VPS server and run an Avalanche node

This is a setup script to automate the setup and provisioning of Ubuntu servers. It does the following:
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

* Hardware: 2 GHz or faster CPU, 4 GB RAM, 2 GB hard disk.
* OS: Ubuntu >= 18.04

# Usage
Generate an ssh key on your local machine:
```bash
ssh-keygen -t rsa
cat ~/.ssh/id_rsa.pub
```

SSH into your server using the VPS public IP address: 
```bash
ssh root@10.10.10.10
```

Run the setup script by using this command:
```bash
git clone https://github.com/tdeso/avalanche_setup.git && cd avalanche_setup && bash setup.sh
```

Once done, reboot and SSH into your server using the user you just created:
```bash
ssh user@10.10.10.10 -p [ssh_port]
```

Run the installation script
```bash
git clone https://github.com/tdeso/avalanche_setup.git && cd avalanche_setup && bash install.sh
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

# Supported versions
This setup script has been tested against Ubuntu 14.04, Ubuntu 16.04, Ubuntu 18.04 and Ubuntu 20.04.

# Credits
This uses a slighlty modified version of a VPS setup script taken from [ubuntu-server-setup]https://github.com/jasonheecs/ubuntu-server-setup.
This is inspired from [ablock.io](https://github.com/ablockio/AVAX-node-installer) script, with multiple additions and modifications.  
It installs and uses [basic avalanche cli](https://github.com/jzu/bac), which is Unix CLI wrapper around the Avalanche JSON API that makes issuing simple calls easier.

# Licence
[MIT](https://choosealicense.com/licenses/mit/)
