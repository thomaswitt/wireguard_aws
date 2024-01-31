#!/bin/bash -l
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name $DOMAIN_NAME | jq -r '.HostedZones[0].Id' | cut -d'/' -f3)

WIREGUARD_HOSTNAME="vpn-${AWS_DEFAULT_REGION,,}.${DOMAIN_NAME}"
CHANGE_BATCH=$(jq -n \
                 --arg name $WIREGUARD_HOSTNAME \
                 --arg value "$WIREGUARD_IP" \
                 '{
                   Comment: "Create an A record for VPN",
                   Changes: [
                     {
                       Action: "UPSERT",
                       ResourceRecordSet: {
                         Name: $name,
                         Type: "A",
                         TTL: 300,
                         ResourceRecords: [
                           { Value: $value }
                         ]
                       }
                     }
                   ]
                 }')

aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch "$CHANGE_BATCH"

echo "Hostname is: $WIREGUARD_HOSTNAME"
