#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run via sudo as root"; exit 1
fi

echo "# Reseting..."

cd /etc/wireguard

# Delete the folder with customer data
rm -rf ./clients

# Zero IP counter
echo "1" > last_used_ip.var

# Resetting the server configuration template to default settings
cp -f wg0.conf.def wg0.conf

systemctl stop wg-quick@wg0
wg-quick down wg0

echo "# Reseted"
