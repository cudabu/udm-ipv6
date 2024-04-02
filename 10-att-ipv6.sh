```bash
#! /bin/sh
# set -eo pipefail

# Get DataDir location
DATA_DIR="/data"
case "$(ubnt-device-info firmware || true)" in
1*)
  DATA_DIR="/mnt/data"
  ;;
2*)
  DATA_DIR="/data"
  ;;
3*)
  DATA_DIR="/data"
  ;;
*)
  echo "ERROR: No persistent storage found." 1>&2
  exit 1
  ;;
esac

# Check if the container exists
if ! machinectl status att-ipv6 >/dev/null 2>&1; then
    echo "The container 'att-ipv6' is not running. Existing the script."
    exit 1
fi

wan_iface="eth8"                                     # "eth9" for UDM Pro WAN2
vlans="br4 br6 br7 br16 br18 br20 br22"              # "br0 br100 br101..."
domain="cudabu.io"                                   # DNS domain
dns6="[2600:1700:1bd0:17ac::c0a8:703],[2606:4700:4700::1001]" # Cloudflare DNS

confdir=${DATA_DIR}/containers/att-ipv6

# main

test -f "${confdir}/etc/dhcpcd.conf" || {
  : >"${confdir}/etc/dhcpcd.conf.tmp"
  cat >>"${confdir}/etc/dhcpcd.conf.tmp" <<EOF
allowinterfaces ${wan_iface}
nodev
noup
ipv6only
nooption domain_name_servers
nooption domain_name
duid
persistent
option rapid_commit
option interface_mtu
require dhcp_server_identifier
slaac private
noipv6rs

interface ${wan_iface}
  ipv6rs
  ia_na 0
EOF

  ix=0
  for vv in $vlans; do
    echo "  ia_pd ${ix} ${vv}/0"
    ix=$((ix + 1))
  done >>"${confdir}/etc/dhcpcd.conf.tmp"
  mv "${confdir}/etc/dhcpcd.conf.tmp" "${confdir}/etc/dhcpcd.conf"
}

test -f "${confdir}/tmp/att-ipv6-dnsmasq.conf" || {
  : >"${confdir}/tmp/att-ipv6-dnsmasq.conf.tmp"
  cat >>"${confdir}/tmp/att-ipv6-dnsmasq.conf.tmp" <<EOF
#
# via att-ipv6
#
enable-ra
no-dhcp-interface=lo
no-ping
EOF

  for vv in $vlans; do
    cat <<EOF

interface=${vv}
dhcp-range=set:att-ipv6-${vv},::2,::7d1,constructor:${vv},slaac,ra-names,64,86400
dhcp-option=tag:att-ipv6-${vv},option6:dns-server,${dns6}
domain=${domain}|${vv}
ra-param=${vv},high,0
EOF
  done >>"${confdir}/tmp/att-ipv6-dnsmasq.conf.tmp"
  mv "${confdir}/tmp/att-ipv6-dnsmasq.conf.tmp" "${confdir}/tmp/att-ipv6-dnsmasq.conf"
}

# Fix DHCP, assumes DHCPv6 is turned off in UI
cp "${confdir}/tmp/att-ipv6-dnsmasq.conf" /run/dnsmasq.conf.d/
start-stop-daemon -K -q -x /usr/sbin/dnsmasq