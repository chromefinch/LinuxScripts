#!/usr/bin/env bash
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
userid=$SUDO_USER
time=$(date | sed "s/ /_/g")

pwd
read -p "Where are we backing up to? (absolute path only) " bkpath
test -d $bkpath&&echo 'Path already created'||mkdir -p $bkpath;
echo backing up to $bkpath
virsh list --all
echo "Which VM are we trying to backup? "
read -p "Notice this VM will be powered down. " vmname
virsh shutdown $vmname >> /dev/null 2>&1
drives=$(virsh domblklist $vmname | grep -o \/.*)
for drive in $drives; do
	echo " "
	echo VM $vmname drive $drive is being copied to $bkpath
	rsync --info=progress2 $drive $bkpath
done
echo " "
echo copying xml to $bkpath
virsh dumpxml $vmname >> $bkpath/$vmname.xml
echo check files for accuracy
ls -lah $bkpath
read -p "Would you like to zip this? (y/N)" yn
case $yn in
    [yY] ) echo compressing to $vmname.$time.bk ;
        7z a $vmname.$time.bk $bkpath;;
    * ) echo "Skipping compress ";;
esac

