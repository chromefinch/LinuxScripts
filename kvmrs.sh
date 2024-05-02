#!/usr/bin/env bash

sudo -n true
test $? -eq 0 || exit 1 "you should have sudo privilege to run this script"
echo "This VM restore script assumes you previously backed up with kvmbk.sh, that you are using qcow2 disks, and those disks were originally stored in the same location/dir"
echo ""
userid=$SUDO_USER
echo "current dir"
pwd
sleep 3
read -p "Where are backup files? (absolute path only) " bkpath
echo "Listing found backup files:"
ls -lah $bkpath
cd $bkpath
echo ""
echo "Listing existing VM's" 
virsh list --all
read -p "Are you replacing/restoring an existing VM? (y/N)" yn
case $yn in
    [yY] ) echo "Which VM are we trying to restore? ";
    	echo "";
	read -p "Notice this VM will be powered down and deleted. " vmname;
	virsh shutdown $vmname >> /dev/null 2>&1;
	virsh undefine --nvram $vmname >> /dev/null 2>&1;
	virsh undefine $vmname >> /dev/null 2>&1;
	echo "These disk will be overwritten: ";
	dst=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2"| sed "s/'//g");
	dest=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u);
	echo $dst;
	drives=$(ls -lah $bkpath | grep -Eo "$vmname\S+" | grep -Ev ".xml");
	  	for drive in $drives; do 
			echo " "
			echo VM $vmname drive $drive is being copied to $dest
			rsync --info=progress2 $drive $dest
		done;
	echo "";
	echo Importing xml;
   	virsh define --file $bkpath/$vmname.xml;
    	virsh list --all;
	echo "Done!";;
    * ) foundname=$(cat $bkpath/*.xml| grep -Eo "name>\S+<"| sed "s/name>//g" | sed "s/<//g");
	    read -p "What is the VM name? [$foundname]" qvmname;
	    vmname=${qvmname:-$foundname};
	    echo "permanent changes imminent!";
	    sleep 5 ;
	    echo "Renaming system name in xml and for disks...";
	    cp $foundname.xml bk.xml;
	    sed -z -i "s/$foundname/$vmname/g" $foundname.xml;
	    newuuid=$(uuidgen);
	    sed -z -i "s|<uuid>.*</uuid>|<uuid>$newuuid</uuid>|g" $foundname.xml;
	    rename s/$foundname/$vmname/g * ;
	    dest=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u);
	    read -p "Where would you like to restore disks to [$dest]? " qdest;
	    dst=${qdest:-$dest};
	    test $dst&&echo 'Path already exists, proceeding'||mkdir -p $dst;
	    drives=$(ls -lah $bkpath | grep -Eo "$vmname\S+" | grep -Ev ".xml");
	  	for drive in $drives; do 
			echo " "
			echo VM $vmname drive $drive is being copied to $dst
			rsync --info=progress2 $drive $dst
		done;
	    echo "";
	    echo Importing xml;	   
	    virsh define --file $bkpath/$vmname.xml;
	    virsh list --all;
	    echo "Done!";;
esac


