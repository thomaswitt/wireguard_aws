#!/bin/bash -l

# Associate Instance with Elastic IP
ALLOCATION_ID=$(aws ec2 allocate-address | jq -r '.AllocationId')
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID
WIREGUARD_IP=$(aws ec2 describe-addresses --filters "Name=allocation-id,Values=$ALLOCATION_ID" --query 'Addresses | [-1].PublicIp' --output text)

echo "IP is: $WIREGUARD_IP"
