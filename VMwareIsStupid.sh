#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi

vmwarefile='VMware-Workstation-Full-17.5.2-23775571.x86_64.bundle'
vmwareE='VMware-Workstation-Full-17.5.2-23775571.x86_64.bundle'
vmwareversion='17.5.2'
vmwareFIXversion='17.5.0'
userid=$SUDO_USER

echo Lets install VMware Workstation $vmwareversion
echo downloading $vmwareE...
test -f /home/$userid/Downloads/$vmwareE&&echo 'VMware already downloaded' || echo please download $vmwarefile and put it in /home/$userid/Downloads
echo getting fixes
wget https://github.com/mkubecek/vmware-host-modules/archive/workstation-$vmwareFIXversion.tar.gz
tar -xzf workstation-$vmwareFIXversion.tar.gz
cd vmware-host-modules-workstation-$vmwareFIXversion
tar -cf vmmon.tar vmmon-only
tar -cf vmnet.tar vmnet-only
sudo chown $userid:$userid /home/$userid/Downloads/*
sudo bash /home/$userid/Downloads/$vmwareE --eulas-agreed --console
cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/
sudo vmware-modconfig --console --install-all
echo "if there are VMware service failures (vmmon vmnet) or anyother VMware issues, check if SecureBoot is enabled and visit; https://www.centennialsoftwaresolutions.com/post/ubuntu-20-04-3-lts-and-vmware-issues"
echo this is dumb
vmware --version
