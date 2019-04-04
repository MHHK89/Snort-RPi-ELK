#!/bin/bash
# Script to install and Setup Beats on RPi
# Caution: script may no work for some users, specially path not found error  or mage related errors may be encountered
# In such case rerunning export PATH=$PATH:/usr/local/go/bin may work
# Install dependencies

sudo apt-get install python-pip git
sudo pip install virtualenv
sudo wget https://dl.google.com/go/go1.12.1.linux-armv6l.tar.gz
#sudo wget https://dl.google.com/go/go1.11.2.linux-armv6l.tar.gz
sudo tar -C /usr/local/ -xzf go1.*.linux-armv6l.tar.gz
export PATH=$PATH:/usr/local/go/bin



# if bash related error is encountered, 
#add following in file ~/ .profile ,adding same to /etc/bash.bashrc may also work.
##
#export PATH=$PATH:/usr/local/go/bin 
#sudo chmod a+x ~/.profile  # or /etc/bash.bashrc

# verify Go 
echo "Go version is.."
sleep 3
go version
#sudo swapoff -a
# before installing any beats component, better to increase swap memory for RPi, otherwise low memory error will be thrown.
sudo cat > /etc/dphys-swapfile << EOL
CONF_SWAPFILE=/var/swap
CONF_SWAPSIZE=2048
CONF_MAXSWAP=3000   
EOL

echo  "Checking Swap memory,,,,,, "
 
sudo swapon /var/swap    
sudo service dphys-swapfile stop
sudo service dphys-swapfile start
#sudo /etc/init.d/dphys-swapfile restart
#sleep 3
# verify swap memory by
sudo swapon -s
	
# if "go command not found" error is thrown, provide the path again
#export PATH=$PATH:/usr/local/go/bin

# setting up beats
echo "Downloading and Configuring Beats on your Raspberry Pi....."
sleep 2
cd /home/pi 
mkdir go
# provide permissions
sudo chown -R pi /home/pi/go     # incase of user pi
sudo chown -R pi /usr/local/go 
cd /home/pi/go
mkdir -p src/github.com/elastic
cd src/github.com/elastic
sudo git clone https://github.com/elastic/beats.git
#git checkout
cd beats/filebeat/
export GOPATH=$HOME/go
export GOROOT=/usr/local/go/
export PATH="$GOPATH/bin:$PATH"
# Do not use sudo with make, several errors may be encountered during this phase, better Google them 	
make
