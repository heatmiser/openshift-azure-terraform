# Deprovision and prepare for Azure
waagent -force -deprovision
# Clear shell history
export HISTSIZE=0
# workaround old agent bug
rm -f /etc/resolv.conf 2>/dev/null
