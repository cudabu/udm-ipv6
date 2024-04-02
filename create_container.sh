#!/bin/bash

set -e

container_name="att-ipv6"
container_root_password=""

function create_container() {

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

function setup_networking() {
mkdir -p /etc/systemd/nspawn

cat <<EOF > /etc/systemd/nspawn/"$container_name".nspawn
[Exec]
Boot=on
Capability=all

[Network]
Private=off
VirtualEthernet=off
ResolvConf=off
EOF
}

function setup_persistence() {
cd /data/on_boot.d
curl -LO  https://raw.githubusercontent.com/cudabu/udm-ipv6/main/0-setup-system.sh
chmod +x 0-setup-system.sh

mv 0-setup-system.sh 02-setup-system.sh
}

create_container
setup_networking
setup_persistence