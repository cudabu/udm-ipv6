# udm-ipv6

# About

Notes for running dhcpdf on UDM to pull multiple IPv6 blocks from AT&T

## Problem

On ATT IPv6, the RG (residential gateway) receives a /60 prefix itself, but only hands out one /64 to routers in IP Passthrough mode, regardless how big of a prefix was requested. The RG keeps the lower 8 /64s for its own purposes (`2600:1700:X:yyy0::/63`), and Unifi normally only receives `2600:1700:X:yyyf::/64`.

This script enables UDM to receive up to 8 PDs on ATT IPv6 (tested with RG BGW320-500), usually starting at `2600:1700:X:yyyf::/64` down to `2600:1700:X:yyy8::/64`. Note that these may not always be assigned contiguous or in order.

The price to pay is that almost none of the IPv6 support native to UDM remains enabled, hence options like DHCPv6 cannot be changed in the UI anymore. Firewall and routing rules remain functional, however.


## Install notes

- You manually setup dhcpcdf process
- The script above copies everything into the correct place
- For the nspawn-container you did the `stable` build vs `unstable`
- You ran the container as priviledged


## Uninstallation

From a SSH on UDM
```bash
machinectl disable att-ipv6
machinectl terminate att-ipv6
machinectl removte att-ipv6
rm -rf /data/containers/att-ipv6
rm /run/dnsmasq.d
rm /data/on.boot/10-att-ipv6.sh
rm /run/dnsmasq.conf.d/att-ipv6-dnsmasq.conf
# enable IPv6 in the UI again, see note below.
start-stop-daemon -K -q -x /usr/sbin/dnsmasq

In the UDM GUI go to Network > Settings > Security > Firewall Rules > Internet v6 and delete the rules created previously.
```

## Credit

This is a script I modified. The need for this is based on:
- [unifios-utilities](https://github.com/unifi-utilities/unifios-utilities/blob/main/att-ipv6/README.md)
