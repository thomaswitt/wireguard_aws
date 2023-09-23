#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run via sudo as root"; exit 1
fi

echo "# Removing"

wg-quick down wg0
systemctl stop wg-quick@wg0
systemctl disable wg-quick@wg0

yum remove -y wireguard-tools iptables-services qrencode
yum update -y
yum clean all -y

rm -rf /etc/wireguard
rm -f /etc/sysctl.d/wg-forwarding.conf

echo "# Removed"
