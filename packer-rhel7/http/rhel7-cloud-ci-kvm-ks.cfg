# Kickstart for provisioning a RHEL 7 KVM VM
#version=RHEL7

# System authorization information
auth --enableshadow --passalgo=sha512

# Use text mode install
text
# Firewall configuration
firewall --disabled

# Do not run the Setup Agent on first boot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# Network information
network  --bootproto=dhcp --device=link
network  --hostname=cloud-ci-kvm

# Root password
rootpw changeme
#rootpw --plaintext "somepassword"
# Root password
#rootpw --iscrypted HarTSZDmT7X/Y

# System services
services --enabled="sshd,dnsmasq,NetworkManager,chronyd"

# System timezone
timezone Etc/UTC --isUtc --ntpservers 0.rhel.pool.ntp.org,1.rhel.pool.ntp.org,2.rhel.pool.ntp.org,3.rhel.pool.ntp.org

# Partition clearing information
clearpart --all --initlabel

# Clear the MBR
zerombr

# Disk partitioning information
part /boot --fstype="xfs" --size=250
part / --fstype="xfs" --size=1 --grow --asprimary

# System bootloader configuration
bootloader --location=mbr

# Firewall configuration
firewall --disabled

# Enable SELinux
selinux --enforcing

# Don't configure X
skipx

# Accept the eula
eula --agreed

# Reboot the machine after successful installation
reboot --eject

%packages --nobase
@core --nodefaults
chrony
sudo
parted
deltarpm
openssh-clients
openssh-server
@console-internet
-dracut-config-rescue
-aic94xx-firmware*
-alsa-*
-biosdevname
-btrfs-progs*
-dracut-network
-iprutils
-ivtv*
-iwl*firmware
-libertas*
-kexec-tools
-NetworkManager*
-plymouth*

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Register Red Hat Subscription
subscription-manager register --username=rhnuser@domain.com --password=rhnpassword --auto-attach --force
subscription-manager repos --disable="*"
subscription-manager repos --enable="rhel-7-server-rpms"

# Install latest repo update
yum update -y

# Unregister Red Hat subscription
#subscription-manager unregister
# this has to be moved to final packer script, otherwise won't run be able to update

# Disable the root account
# usermod root -p '!!'
# rootpw --plaintext redhat1

# Set the cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0"/g' /etc/default/grub
sed -i 's/ rhgb//g' /etc/default/grub
sed -i 's/ quiet//g' /etc/default/grub
sed -i 's/ crashkernel=auto//g' /etc/default/grub

# Build the grub cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

# Enable SSH keepalive
sed -i 's/^#\(ClientAliveInterval\).*$/\1 180/g' /etc/ssh/sshd_config

## Configure network
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
NM_CONTROLLED=no
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

%end

%addon com_redhat_kdump --disable --reserve-mb='auto'

%end
