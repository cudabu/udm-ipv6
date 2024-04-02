#!/bin/bash

set -e

container_name="att-ipv6"
container_root_password=""

vlan_id=7
vlan_address="192.168.7.3/24"
vlan_gateway="192.168.7.2"

function create_custom_container() {

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
curl -LO https://raw.githubusercontent.com/cudabu/udm-ipv6/main/10-setup-network.sh
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

function setup_persistence() {
cd /data/on_boot.d
curl -LO  https://raw.githubusercontent.com/cudabu/udm-ipv6/main/0-setup-system.sh
chmod +x 0-setup-system.sh

mv 0-setup-system.sh 02-setup-system.sh
}

# Call the menu function
create_custom_container
setup_networking_macvlan
setup_persistence