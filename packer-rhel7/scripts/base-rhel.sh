# Register Red Hat Subscription
subscription-manager register --username="$rhn_username_org" --password="$rhn_password_act_key" && subscription-manager attach --pool="$rhn_pool_id" || subscription-manager register --activationkey="$rhn_password_act_key" --org="$rhn_username_org"
subscription-manager repos --disable="*"
subscription-manager repos --enable="rhel-7-server-rpms"
# Install latest repo update
yum update -y
yum -y update
yum -y install wget curl

# Install root certificates
yum -y install ca-certificates

# Only install cloud-init on "cloud-ci-" hostname systems

if hostname -f|grep -e "cloud-ci-" >/dev/null
then
   echo $(date) " - Installing cloud-init"
   subscription-manager repos --enable=rhel-7-server-rh-common-rpms
   yum -y install cloud-init
   systemctl enable cloud-init
fi
