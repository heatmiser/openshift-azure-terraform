# install official epel package
# @see https://fedoraproject.org/wiki/EPEL
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7Server
rpm -Uvh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

yum -y update
