# Install and use AWS-based Wireguard

Scripts to automate install and use of Wireguard on AWS with Amazon Linux 2023.
Choose a t4g.micro 64-bit (Arm) instance with Amazon Linux 2023 AMI.

## Preparation in the AWS console
- Choose desired region and create Elastic IP
- Import your SSH keypair
- Create a security group wireguard with inbound rules from any IP
  - Allow incoming ssh (TCP 22 or eg TCP 443 if non default port)
  - Allow UDP 443 for WireGuard.
  - Allow UDP 60000-61000 for mosh
  - Allow Custom ICMP Echo Request
- Launch t4g.micro Amazon Linux 2 AMI (aarch64)
  - Start with all defaults, but
  - Assign Security Group
  - Enable Instance auto-recovery
  - Change Storage to Encrypted with default key (Advanced EBS option)
  - Choose your existing imported keypair at launch
- Go to Elastic IPs and associate your Elastic IP to the new instance
  - Potentially set a route53 hostname
- ssh into new instance (ssh ec2-user@AWS-IP)
- Harden sshd_config and consider changing default ssh port

## Installation
```
sudo yum upgrade
sudo yum install git tmux -y

git clone https://github.com/thomaswitt/dotfiles.git
sudo cp dotfiles/etc/bashrc.local /etc/profile.d/bashrc.local.sh
sudo cp dotfiles/etc/issue.net /etc
sudo cp /etc/ssh/ssh_config /etc/ssh/ssh_config.orig
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
sudo cp dotfiles/etc/issue.net /etc
sudo cp dotfiles/etc/ssh/* /etc/ssh
# consider changing default port to 443 or something else
# sudo sed -i 's/^# Port 443/Port 443/' /etc/ssh/sshd_config
sudo sed -i 's/^# AllowUsers ec2-user/AllowUsers ec2-user/' /etc/ssh/sshd_config
sudo sh -c 'grep Subsystem /etc/ssh/sshd_config.orig >>/etc/ssh/sshd_config'
sudo sshd -T && sudo service sshd restart # Re-Login now if you changed the port

git clone https://github.com/thomaswitt/wireguard_aws.git wireguard_aws &&
cd wireguard_aws && sudo ./initial.sh # accept defaults
```

The `initial.sh` script ...
- removes the previous Wireguard installation (if any) using the `remove.sh` script,
- installs and configures the Wireguard service using the `install.sh` script,
- reboots the server.

Connect again via ssh or mosh.

### Add new client
`add-client.sh` - Script to add a new VPN client. Run via sudo. As a result of the execution, it creates a configuration file ($CLIENT_NAME.conf) on the path ./clients/$CLIENT_NAME/, displays a QR code with the configuration.

```
sudo ~ec2-user/wireguard_aws/add-client.sh
#OR
sudo ~ec2-user/wireguard_aws/add-client.sh johnDoe@iPadPro
```

### Reset all clients
`reset.sh` - script that removes information about clients. And stopping the VPN server Winguard
```
sudo ~ec2-user/wireguard_aws/reset.sh
```

### Delete Wireguard
```
sudo ~ec2-user/wireguard_aws/remove.sh
```

## Optional: Install Mosh
```
sudo yum -y remove mosh
sudo yum -y groupinstall 'Development Tools'
sudo yum -y install protobuf-devel protobuf-compiler ncurses-devel openssl-devel
git clone https://github.com/mobile-shell/mosh
cd mosh
./autogen.sh
./configure --enable-asan
make
make check
sudo make install
```

# Authors
- Thomas Witt (Adapted to AWS Linux)
- Alexey Chernyavskiy (Original version)
