#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run via sudo as root"; exit 1
fi

echo "# Installing Wireguard (intial)"

./remove.sh
./install.sh

echo "# Wireguard installed. Now rebooting. Login in and add a client via add-client.sh."
