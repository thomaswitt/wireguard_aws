# Install and use AWS-based Wireguard

Scripts to automate install and use of Wireguard on AWS with Amazon Linux 2023.
Choose a t4g.micro 64-bit (Arm) instance with Amazon Linux 2023 AMI.

## Preparation in the AWS console

### Automated

Automated example with AWS CLI:

```bash
# AWS CLI Defaults
export AWS_PAGER=""
export AWS_DEFAULT_REGION=eu-central-1
# Or use with 1password CLI: op plugin init aws
export AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials
export AWS_PROFILE=default
DOMAIN_NAME="my-domain-name-in-route53.com" # needs to exists in route53

# Get Account Info
aws account get-contact-information
aws sts get-caller-identity

# Create resources
source aws-create-resources.sh

# Associate Elastic IP (wait until instance has booted up)
source aws-elastic-ip.sh

# Optional: Associate Route53
source aws-create-route53-record.sh

# Add the entry to ~/.ssh/config
HOST_ENTRY=$(echo $WIREGUARD_HOSTNAME | cut -d '.' -f 1)
echo -e "\nHost $HOST_ENTRY\n  # IP: $WIREGUARD_IP\n  HostName $WIREGUARD_HOSTNAME\n  HostKeyAlias $WIREGUARD_HOSTNAME\n  Port 443\n  User ec2-user" >> ~/.ssh/config
echo -e "\nHost ${HOST_ENTRY}-forward\n  # IP: $WIREGUARD_IP\n  HostName $WIREGUARD_HOSTNAME\n  HostKeyAlias $WIREGUARD_HOSTNAME\n  Port 443\n  User ec2-user\n  ForwardAgent yes\n  DynamicForward localhost:1080\n  ExitOnForwardFailure yes" >> ~/.ssh/config
```

### Manual

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

# ssh into instance

`ssh ec2-user@${WIREGUARD_HOSTNAME} # or ssh ec2-user@${WIREGUARD_IP}`

## Install all updates

```bash
ssh ec2-user@${WIREGUARD_HOSTNAME} '
sudo yum upgrade -y &&
sudo yum install git vim tmux bind-utils -y &&
sudo dnf upgrade --refresh -y &&
sudo dnf upgrade --releasever=latest -y &&
sudo reboot'
```

## Installation

```bash
ssh ec2-user@${WIREGUARD_HOSTNAME}

git clone https://github.com/thomaswitt/wireguard_aws.git wireguard_aws

cp -r wireguard_aws/etc/ssh/rc .ssh/rc
sudo cp wireguard_aws/etc/issue.net /etc
sudo cp -r wireguard_aws/etc/ssh/* /etc/ssh
sudo sed -i 's/^#Port 22/Port 443/' /etc/ssh/sshd_config # default port 443
sudo sshd -T && sudo service sshd restart # Re-Login now if you changed the port

cd wireguard_aws && sudo UNATTENDED="true" ./initial.sh
```

The `initial.sh` script ...

- removes the previous Wireguard installation (if any) using the `remove.sh` script,
- installs and configures the Wireguard service using the `install.sh` script,
- reboots the server.

Connect again via ssh or mosh and add clients in the next step

### Add new client

`add-client.sh` - Script to add a new VPN client. Run via sudo. As a result of the execution, it creates a configuration file ($CLIENT_NAME.conf) on the path ./clients/$CLIENT_NAME/, displays a QR code with the configuration.

```bash
ssh ec2-user@${WIREGUARD_HOSTNAME}
sudo ~ec2-user/wireguard_aws/add-client.sh
#OR
sudo ~ec2-user/wireguard_aws/add-client.sh johnDoe@iPadPro
```

### List current clients

```bash
sudo bash -c 'for file in $(ls -1 /etc/wireguard/clients); do echo $file; qrencode -t ansiutf8 </etc/wireguard/clients/$file/$file.conf; echo; done'
```

### Reset all clients

`reset.sh` - script that removes information about clients. And stopping the VPN server Winguard

```bash
sudo ~ec2-user/wireguard_aws/reset.sh
```

### Delete Wireguard

```bash
sudo ~ec2-user/wireguard_aws/remove.sh
```

## Optional: Install Mosh

```bash
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

## Optional: Update sshd

```bash
sudo yum install -y gcc openssl-devel zlib-devel mlocate autoconf systemd-devel pam-devel
curl -O https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.9p1.tar.gz
tar xvfz openssh-*.tar.gz
cd $(basename openssh-*.tar.gz .tar.gz)
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-default-path=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin && make
sudo make install
/usr/sbin/sshd -t -f /etc/ssh/sshd_config
mkdir /etc/ssh/sshd_config.d /etc/ssh/ssh_config.d
echo "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a /etc/ssh/sshd_config
echo "Include /etc/ssh/ssh_config.d/*.conf" | sudo tee -a /etc/ssh/ssh_config
systemctl restart sshd.service
```

# Authors

- Thomas Witt (Adapted to AWS Linux)
- Alexey Chernyavskiy (Original version)
