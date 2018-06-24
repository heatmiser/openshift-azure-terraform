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
