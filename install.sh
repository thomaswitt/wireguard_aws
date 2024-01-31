#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run via sudo as root"; exit 1
fi

function read_input() {
    local prompt=$1
    local default_value=$2
    local var_name=$3

    if [ -z "$UNATTENDED" ]; then
        read -e -p "$prompt " -i "$default_value" input_value
        if [ -z "$input_value" ]; then
            echo "[#]Empty $var_name. Exit"
            exit 1
        fi
    else
        input_value=$default_value
    fi

    declare -g $var_name="$input_value"
}

echo "Installing utils"
yum install -y yum-utils dnf-automatic
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
sed -i 's/emit_via = stdio/emit_via = motd/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer

echo "Installing wireguard packages"
yum install -y wireguard-tools iptables-services qrencode
yum update -y
yum clean all -y

echo "Preparing system"
sysctl net.ipv4.ip_forward=1 | tee -a /etc/sysctl.d/wg-forwarding.conf
sysctl net.ipv4.conf.all.forwarding=1 | tee -a /etc/sysctl.d/wg-forwarding.conf
systemctl enable wg-quick@wg0.service

cd /etc/wireguard

umask 077

SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo $SERVER_PRIVKEY | wg pubkey)
echo $SERVER_PUBKEY >./server_public.key
echo $SERVER_PRIVKEY >./server_private.key

TOKEN=$(curl -s --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")

EXT_IP=`curl -s http://169.254.169.254/latest/meta-data/public-ipv4 --header "X-aws-ec2-metadata-token: $TOKEN"`
read_input "Enter the endpoint (external ip and port) in format [ipv4:port]:" "${EXT_IP}:443" "ENDPOINT"
if [ -z $ENDPOINT ]; then echo "[#]Empty ENDPOINT. Exit"; exit 1; fi
echo $ENDPOINT > ./endpoint.var

INTERFACE=`networkctl list --no-legend --no-pager|grep ether|cut -d ' ' -f 4`

ifconfig $INTERFACE || exit "Networking interface $INTERFACE does not exist"
INT_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4 --header "X-aws-ec2-metadata-token: $TOKEN"`
  read_input "Enter the server address in the VPN subnet (CIDR format), [ENTER] set to default:" $INT_IP "SERVER_IP"
if [ -z $SERVER_IP ]; then echo "[#]Empty SERVER IP. Exit"; exit 1; fi
echo $SERVER_IP | grep -o -E '([0-9]+\.){3}' > ./vpn_subnet.var

read_input "Enter the ip address of the server DNS (CIDR format), [ENTER] set to default: " "1.1.1.1" "DNS"
if [ -z $DNS ]; then echo "[#]Empty DNS. Exit"; exit 1; fi
echo $DNS > ./dns.var

echo 1 > ./last_used_ip.var

read_input "Enter the name of the WAN network interface ([ENTER] set to default: " "$INTERFACE" "WAN_INTERFACE_NAME"
if [ -z $WAN_INTERFACE_NAME ]; then echo "[#]Empty WAN. Exit"; exit 1; fi
echo $WAN_INTERFACE_NAME > ./wan_interface_name.var

cat ./endpoint.var | sed -e "s/:/ /" | while read SERVER_EXTERNAL_IP SERVER_EXTERNAL_PORT
do
cat > ./wg0.conf.def << EOF
[Interface]
Address = $SERVER_IP
SaveConfig = false
PrivateKey = $SERVER_PRIVKEY
ListenPort = $SERVER_EXTERNAL_PORT
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $WAN_INTERFACE_NAME -j MASQUERADE;
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $WAN_INTERFACE_NAME -j MASQUERADE;
EOF
done

cp -f ./wg0.conf.def ./wg0.conf

systemctl enable wg-quick@wg0

echo "=== REBOOTING"
reboot
