# Configure serial console
yum -y install grub2-tools

# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sec-GRUB_2_over_Serial_Console.html#sec-Configuring_GRUB_2
# already did this in kickstart?
#cat > /etc/default/grub <<EOF
#GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=true
#GRUB_TIMEOUT=1
#GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
#GRUB_DEFAULT=saved
#GRUB_DISABLE_SUBMENU=true
#GRUB_TERMINAL=serial
#GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
#GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"
#GRUB_TERMINAL_OUTPUT="console"
#GRUB_DISABLE_RECOVERY="true"
#EOF

#grub2-mkconfig -o /boot/grub2/grub.cfg

# Register Red Hat Subscription
subscription-manager register --username="$rhn_username_org" --password="$rhn_password_act_key" && subscription-manager attach --pool="$rhn_pool_id" || subscription-manager register --activationkey="$rhn_password_act_key" --org="$rhn_username_org"
subscription-manager repos --disable="*"
subscription-manager repos --enable="rhel-7-server-rpms"
# Install latest repo update
yum update -y

# Enable extras repo
subscription-manager repos --enable="rhel-7-server-extras-rpms"

# Install WALinuxAgent
yum install -y WALinuxAgent
systemctl enable waagent.service

# Unregister Red Hat subscription
#subscription-manager unregister
# this has to be moved to final packer script, otherwise won't run be able to update

# Enable waaagent at boot-up
systemctl enable waagent

# Disable the root account
# usermod root -p '!!'

# Configure swap in WALinuxAgent
sed -i 's/^\(ResourceDisk\.EnableSwap\)=[Nn]$/\1=y/g' /etc/waagent.conf
sed -i 's/^\(ResourceDisk\.SwapSizeMB\)=[0-9]*$/\1=2048/g' /etc/waagent.conf

# Set the cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0"/g' /etc/default/grub
sed -i 's/ rhgb//g' /etc/default/grub
sed -i 's/ quiet//g' /etc/default/grub
sed -i 's/ crashkernel=auto//g' /etc/default/grub

# Build the grub cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

# make Hyper-V device drivers available
cat >> /etc/dracut.conf <<EOF
add_drivers+=" hv_vmbus "
add_drivers+=" hv_netvsc "
add_drivers+=" hv_storvsc "
EOF

# regenerate the intramfs image
dracut -f -v

# remove uuid
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-e*
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-e*

# Disable persistent net rules
touch /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null

# Install haveged for entropy, epel is required
#yum -y install haveged

# Installs cloudinit, epel is required
#yum -y install cloud-init

# configure cloud init 'cloud-user' as sudo
# this is not configured via default cloudinit config
if [ -d "/etc/cloud/cloud.cfg.d" ]; then
cat > /etc/cloud/cloud.cfg.d/02_user.cfg <<EOL
system_info:
  default_user:
    name: cloud-user
    lock_passwd: true
    gecos: Cloud user
    groups: [wheel, adm]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
EOL
fi

/usr/bin/yum -y install sudo
### Uncoment below if additional system user is desired, change cloudse to whatever username
### Plus add ssh-rsa line to include ssh public key
#/usr/sbin/groupadd cloudse
#/usr/sbin/useradd cloudse -g cloudse -G wheel
#####echo "cloudse"|passwd --stdin someFunkyPassword
#echo "cloudse        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/cloudse
#chmod 0440 /etc/sudoers.d/cloudse
#
#mkdir /home/cloudse/.ssh
#cat <<EOF >/home/cloudse/.ssh/authorized_keys
#ssh-rsa AAAB3nZaC1aycAAEU+/ZdulUJoeuchOUU02/j18L7fo+ltQ0f322+Au/9yy9oaABBRCrHN/yo88BC0AB3nZaC1aycAAEU+/ZdulUJoeuchOUU02/j18L7fo+ltQ0f322AB3nZaC1aycAAEU+/ZdulUJoeuchOUU02/j18L7fo+ltQ0f322AB3nZaC1aycAAEU+/ZdulUJoeuchOUU02/j18L7fo+ltQ0f322AB3nZaC1aycAAEU+/ZdulUJoeuchOUU02/j18L7fo+ltQ0f322klCi0/aEBBc02N+JJP cloudse@domain.com
#EOF
#
#### set ownership and permissions
#chown -R cloudse.cloudse /home/cloudse/.ssh
#chmod -R 0700 /home/cloudse/.ssh
#chmod 0600 /home/cloudse/.ssh/authorized_keys
