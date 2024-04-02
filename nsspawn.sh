#!/bin/bash

set -e

container_name="att-ipv6"
container_root_password=""

vlan_id=7
vlan_address="192.168.7.3/24"
vlan_gateway="192.168.7.2"


##
# Color  Variables
##
green='\e[32m'
blue='\e[34m'
clear='\e[0m'

##
# Color Functions
##

ColorGreen(){
	echo -ne $green$1$clear
}
ColorBlue(){
	echo -ne $blue$1$clear
}


function create_custom_container_macvlan(){
    echo "You have selected to setup a container to use an Isolated MacVLAN Network AKA Vlan."
    read -p "Press enter to continue OR  ctrl + c  to cancel."
    create_custom_container ;
    setup_networking_MACVLAN ;
    setup_persistence ;
    setup_backup_dpkg_files
}

function create_custom_container() {
    echo ""
	echo " Creating a Custom Container on UnifiOS 3.x"
    echo ""

#### check if directory exists and abort

if [ -d "/data/custom/machines/$container_name" ] 
then
    echo "Directory /data/custom/machines/$container_name already exists"
fi

### Create the Container
apt -y install systemd-container debootstrap
mkdir -p /data/custom/machines
cd /data/custom/machines
debootstrap --include=systemd,dbus unstable "$container_name"
systemd-nspawn -M "$container_name" -D /data/custom/machines/"$container_name" /bin/bash -c "echo 'root:${container_root_pasword}' | chpasswd"
systemd-nspawn -M "$container_name" -D /data/custom/machines/"$container_name" /bin/bash -c systemctl enable systemd-networkd
systemd-nspawn -M "$container_name" -D /data/custom/machines/"$container_name" /bin/bash -c echo "nameserver 1.1.1.1" > /etc/resolv.conf \
echo ""$container_name"" > /etc/hostname 
echo "Linking the container to /var/lib/machines"
mkdir -p /var/lib/machines
ln -s /data/custom/machines/"$container_name" /var/lib/machines/
}

function setup_networking_macvlan() {
mkdir -p /etc/systemd/nspawn

cat <<EOF > /etc/systemd/nspawn/"$container_name".nspawn
[Exec]
Boot=on

[Network]
MACVLAN=br$vlan_id
ResolvConf=off
EOF

##### Configure the Container to use an Isolated MacVLAN Network
cd /data/on_boot.d
if [ -f "$file" ] ; then
    rm "$file"
fi
curl -LO https://raw.githubusercontent.com/peacey/unifios-utilities/nspawn/nspawn-container/scripts/10-setup-network.sh
chmod +x 10-setup-network.sh

cat <<EOF > /etc/systemd/nspawn/"$container_name".nspawn
[Exec]
Boot=on

[Network]
MACVLAN=br$vlan_id
ResolvConf=off
EOF

#####Configure your container to set the IP and gateway you defined in 10-setup-network.sh
cd /data/custom/machines/"$container_name"/etc/systemd/network

cat <<EOF > mv-br${vlan_id}.network
[Match]
Name=mv-br$vlan_id

[Network]
IPForward=yes
Address=$vlan_address
Gateway=$vlan_gateway
EOF

#### Run the 10-setup-network.sh script to setup the network interface
/data/on_boot.d/10-setup-network.sh
machinectl stop "$container_name"
machinectl start "$container_name"

}



systemd-nspawn -M "$container_name" -D /data/custom/machines/"$container_name" /bin/bash -c "apt -y install curl &&
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v"


echo "Go to http://${vlan_address}:3000 to configure AdGuard Home (or whatever IP your container has if you had select simple install)."
read -p "Press enter to continue"

}

function setup_persistence() {
    echo ""
	echo " Configuring Persistence Across Firmware Updates"
    echo ""
#### Configure Persistence Across Firmware Updates
echo "Configuring Persistence Across Firmware Updates" 
cd /data/on_boot.d
curl -LO https://raw.githubusercontent.com/peacey/unifios-utilities/nspawn/nspawn-container/scripts/0-setup-system.sh
chmod +x 0-setup-system.sh

mv 0-setup-system.sh 02-setup-system.sh
}

function setup_backup_dpkg_files() {
    echo ""
	echo " Downloading the backup dpkg package files"
    echo ""
#### Download the backup dpkg package files for systemd-container and dependencies into /data/custom/dpkg. 
#####These packages will only be used as a backup install in case the Internet is down after the first boot after an update.
echo "Configuring backup install"
mkdir -p /data/custom/dpkg && cd /data/custom/dpkg
apt download systemd-container libnss-mymachines debootstrap arch-test

echo " Container setup has ended .. :) "
}

menu(){
echo -ne "
Create a container with systemd-nspawn
Select your option from below:
$(ColorGreen '1)') Create a Custom Container Simple
$(ColorGreen '2)') Create a Custom Container Mac Vlan
$(ColorGreen '3)') Install Adguard in existing container.
$(ColorGreen '4)') Print set Variables.
$(ColorGreen '5)') Set Container Variables (name & Root Password).
$(ColorGreen '6)') Set Container Network Variables. (Vlan ID & IP address).
$(ColorGreen '0)') Exit
$(ColorBlue 'Choose an option:') "
        read a
        case $a in
	        1) create_custom_container_simple ; menu ;;
	        2) create_custom_container_macvlan ; menu ;;
	        3) setup_adguard ; menu ;;
            4) echo_variables ; menu ;;
            5) set_variables ; menu ;;
            6) set_container_network_variables ; menu ;;
		0) exit 0 ;;
		*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

# Call the menu function
menu