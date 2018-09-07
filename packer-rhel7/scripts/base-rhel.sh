# Register Red Hat Subscription
echo "rhn_username_org     ==> $rhn_username_org"
echo "rhn_password_act_key ==> $rhn_password_act_key"
echo "rhn_pool_id          ==> $rhn_pool_id"
subscription-manager register --username="$rhn_username_org" --password="$rhn_password_act_key" || subscription-manager register --activationkey="$rhn_password_act_key" --org="$rhn_username_org"
if [ "$rhn_pool_id" != "null" ]; then
    subscription-manager attach --pool="$rhn_pool_id"
fi
subscription-manager repos --disable="*"
subscription-manager repos --enable="rhel-7-server-rpms"
# Install latest repo update
yum update -y
yum -y update
yum -y install wget curl iscsi-initiator-utils device-mapper-multipath

# Install root certificates
yum -y install ca-certificates

# Have to reboot to new kernel so dracut operates on correct kernel/drivers
reboot