#!/bin/bash


if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"; exit 1
fi

echo "Installing yum-cron"
yum install -y yum-cron
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf
systemctl start yum-cron.service
systemctl enable yum-cron.service
# Progress can be monitored in `/var/log/yum.log`.

echo "Installing packages"
curl -Lo /etc/yum.repos.d/wireguard.repo \
  https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
amazon-linux-extras install -y epel
yum install -y epel-release wireguard-dkms wireguard-tools iptables-services qrencode
yum update -y
yum clean all -y

echo "Preparing system"
sysctl net.ipv4.ip_forward=1 | tee -a /etc/sysctl.d/wg-forwarding.conf
sysctl net.ipv4.conf.all.forwarding=1 | tee -a /etc/sysctl.d/wg-forwarding.conf
systemctl enable wg-quick@wg0.service

mkdir /etc/wireguard/

cd /etc/wireguard

umask 077

SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo $SERVER_PRIVKEY | wg pubkey)

echo $SERVER_PUBKEY >./server_public.key
echo $SERVER_PRIVKEY >./server_private.key

EXT_IP=`curl -s http://169.254.169.254/latest/meta-data/public-ipv4`
read -e -p "Enter the endpoint (external ip and port) in format [ipv4:port]: " -i "${EXT_IP}:443" ENDPOINT
if [ -z $ENDPOINT ]; then echo "[#]Empty ENDPOINT. Exit"; exit 1; fi
echo $ENDPOINT > ./endpoint.var

ifconfig eth0
INT_IP=`curl -s curl http://169.254.169.254/latest/meta-data/local-ipv4`
  read -e -p "Enter the server address in the VPN subnet (CIDR format), [ENTER] set to default: " -i $INT_IP SERVER_IP
if [ -z $SERVER_IP ]; then echo "[#]Empty SERVER IP. Exit"; exit 1; fi
echo $SERVER_IP | grep -o -E '([0-9]+\.){3}' > ./vpn_subnet.var

read -e -p "Enter the ip address of the server DNS (CIDR format), [ENTER] set to default: " -i "1.1.1.1" DNS
if [ -z $DNS ]; then echo "[#]Empty DNS. Exit"; exit 1; fi
echo $DNS > ./dns.var

echo 1 > ./last_used_ip.var

read -e -p "Enter the name of the WAN network interface ([ENTER] set to default: " -i "eth0" WAN_INTERFACE_NAME
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

echo "Rebooting"
reboot
