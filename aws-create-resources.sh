#!/bin/bash -l

# Create Security Group
GROUP_ID=$(aws ec2 create-security-group --group-name wireguard --description "Wireguard" | jq -r '.GroupId')
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="SSH port 22 IPv4"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,Ipv6Ranges='[{CidrIpv6=::/0,Description="SSH port 22 IPv6"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="SSH port 443"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,Ipv6Ranges='[{CidrIpv6=::/0,Description="SSH port 443 IPv6"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=udp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="Wireguard IPv4"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=udp,FromPort=443,ToPort=443,Ipv6Ranges='[{CidrIpv6=::/0,Description="Wireguard IPv6"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=udp,FromPort=60000,ToPort=61000,IpRanges='[{CidrIp=0.0.0.0/0,Description="mosh IPv4"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=udp,FromPort=60000,ToPort=61000,Ipv6Ranges='[{CidrIpv6=::/0,Description="mosh IPv6"}]'
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=-1,IpRanges='[{CidrIp=0.0.0.0/0,Description="ICMP ping"}]'

# Import SSH Key Pair
KEY_NAME=$(aws ec2 import-key-pair --key-name "Wireguard" --public-key-material fileb://<(head -n 1 ~/.ssh/authorized_keys) | jq -r '.KeyName')

# Find latest Linux AMI and start instance
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=root-device-type,Values=ebs" "Name=state,Values=available" "Name=ena-support,Values=true" "Name=virtualization-type,Values=hvm" "Name=architecture,Values=arm64" "Name=root-device-type,Values=ebs" "Name=name,Values=al2023-ami-ecs-hvm-*-arm64" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t4g.micro --key-name $KEY_NAME --security-group-ids $GROUP_ID --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":true,"VolumeSize":20}}]' --tag-specifications 'ResourceType=instance,Tags=[{Key="Name",Value="wireguard"}]' --instance-initiated-shutdown-behavior stop --credit-specification CpuCredits=standard | jq -r '.Instances[0].InstanceId')

echo "Instance ID in $AWS_DEFAULT_REGION is $INSTANCE_ID"
