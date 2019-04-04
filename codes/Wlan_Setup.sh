#!/bin/bash

# Script to Setup an access point on wlan0 interface of RPi
# using hostapd and isc-dhcp-server
# install required packages

sudo apt-get update
sudo apt-get install hostapd isc-dhcp-server
sudo systemctl stop hostapd
sudo service isc-dhcp-server stop
sudo apt-get install iptables-persistent

# Edit dhcpd.conf
# Modify IP addresses accordingly
 
sudo cat >> /etc/dhcp/dhcpd.conf <<EOL
authoritative;
subnet 192.168.42.0 netmask 255.255.255.0 {
range 192.168.42.1 192.168.42.40;
option broadcast-address 192.168.42.255;
option routers 192.168.42.1,192.168.10.1;
default-lease-time 600;
max-lease-time 7200;
option domain-name "local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOL

# Edit isc-dhcp-server file and add
# make sure wlan0 is down


sudo cat >> /etc/default/isc-dhcp-server <<EOL
INTERFACESv4="wlan0" 
EOL
   
sudo ifdown wlan0


# Edit file /etc/network/interfaces.d/wlan0
# Add following and save file
touch /etc/network/interfaces.d/wlan0
sudo cat >> /etc/network/interfaces.d/wlan0  <<EOL  
allow-hotplug wlan0
iface wlan0 inet static
address 192.168.42.1
netmask 255.255.255.0
EOL
  
  
# Time to enable configure hostapd, hostapd.conf does not exist by default 
sudo touch /etc/hostapd/hostapd.cof
sudo cat >> /etc/hostapd/hostapd.conf <<EOL
interface=wlan0
ssid=Pi_AP    
country_code=NO  
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=yourpassword  
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
wpa_group_rekey=86400
ieee80211n=1
wme_enabled=1

EOL

# Edit /etc/default/hostapd and add following
sudo cat >> /etc/default/hostapd <<EOL
DAEMON_CONF="/etc/hostapd/hostapd.conf"  
EOL


# Enable ipv4 forwarding and add at the end of file
sudo cat >> /etc/sysctl.conf <<EOL
net.ipv4.ip_forward=1
EOL

sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
# Add iptables rules
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
# verify iptable rules by
sudo iptables -t nat -S
echo "setup will resume after 5 seconds......"
sleep 5
# save iptable rules persistently
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
# turn on wlan0 and restart
sudo ifup wlan0
sudo service networking restart
# start services and unmask hostapd
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd
sudo service isc-dhcp-server start
echo " sometimes a reboot can do the magic...."
while true; do

	echo "Do you want to reboot system? [y/n]"
	read OPTION
	case $OPTION in
		Y|y )
			sudo reboot
			break
			;;
		N|n )
			echo "Ok...reboot might solve some erros though!!"
			break
			;;
		* )
			echo "Invalid option, please press y for YES and n for NO"
			;;

	esac

done

# Follow commands can also be used to start daemon services
#sudo update-rc.d hostapd enable 
#sudo update-rc.d isc-dhcp-server enable
