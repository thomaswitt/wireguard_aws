# Install and use AWS-based Wireguard
Scripts to automate install and use of Wireguard on AWS with Amazon Linux 2

## How use


### Preparation in the AWS console
- Choose desired region and create Elastic IP
- Import SSH keypair
- Create security group wireguard and allow incoming tcp 22 and udp 443
- Launch t3a.micro Amazon Linux 2 AMI (5.10, SSD, x86)
  - Start with all defaults, but
  - Assign Security Group
  - Change Storage to Encrypted
  - Choose your existing imported keypair at launch
- Go to Elastic IPs and associate your Elastic IP to the new instance
- ssh into new instance (ssh ec2-user@AWS-IP)

### Installation
```
sudo yum install git -y &&
git clone https://github.com/thomaswitt/wireguard_aws.git wireguard_aws &&
cd wireguard_aws &&
sudo ./initial.sh
```

The `initial.sh` script removes the previous Wireguard installation (if any) using the `remove.sh` script. It then installs and configures the Wireguard service using the `install.sh` script. Afterwards the server reboots. Please connect again vi ssh

### Add new client
`add-client.sh` - Script to add a new VPN client. As a result of the execution, it creates a configuration file ($CLIENT_NAME.conf) on the path ./clients/$CLIENT_NAME/, displays a QR code with the configuration.

```
sudo ~ec2-user/wireguard_aws/add-client.sh
#OR
sudo ~ec2-user/wireguard_aws/add-client.sh johnDoe@iPadPro
```

### Reset customers
`reset.sh` - script that removes information about clients. And stopping the VPN server Winguard
```
sudo ~ec2-user/wireguard_aws/reset.sh
```

### Delete Wireguard
```
sudo ~ec2-user/wireguard_aws/remove.sh
```
## Authors
- Alexey Chernyavskiy (Original version)
- Thomas Witt (Adapted to AWS Linux)
