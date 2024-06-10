#!/usr/bin/env bash
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
echo "This VM restore script assumes you previously backed up with kvmbk.sh and that you are using .qcow2 or .img disks"
echo ""
userid=$SUDO_USER
echo "current dir"
pwd
multidrive () {
	echo "";
	echo Multiple drive paths in xml;
	echo reading xml drives...;
	drives=$(cat $vmname.xml| grep -Eo "'.*\.qcow2|\.img"| sed "s/'//g");
	echo $drives;
	count=1;
	for drive in $drives; do
		ndest=$(echo $drive| grep -Eo ".*\/");
		ndrive=${drive##*/}
		echo ""
		read -p "please enter a drive path for $ndrive [$ndest]: " qdest
		fdest=${qdest:-$ndest}
		echo VM $vmname drive $ndrive is being copied to $fdest
		test $fdest&&echo 'Path already exists, proceeding...'||mkdir -p $fdest
		echo rsync --info=progress2 $ndrive $fdest
		echo Updating xml
		sed -z -i "s|$ndest/$vmname|$fdest/$vmname|g" $vmname.xml
		((count++))
	done;
}
sleep 3
read -p "Where are backup files? (absolute path only) " bkpath
echo "Listing found backup files:"
ls -lah $bkpath
cd $bkpath
echo ""
echo "Listing existing VM's"
virsh list --all
read -p "Are you replacing/restoring an existing VM (y/N)? " yn
case $yn in
    [yY] ) echo "Which VM are we trying to restore? ";
    	echo "";
		foundname=$(cat $bkpath/*.xml| grep -Eo "name>\S+<"| sed "s/name>//g" | sed "s/<//g");
		read -p read -p "Notice this VM will be powered down and deleted. [$foundname]: " qvmname;
		vmname=${qvmname:-$foundname};
		virsh shutdown $vmname >> /dev/null 2>&1;
		virsh undefine --nvram $vmname >> /dev/null 2>&1;
		virsh undefine $vmname >> /dev/null 2>&1;
		destcount=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u| wc -l);
		if [[ $destcount -eq "1" ]] ; then
			dest=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2|\.img"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u)
			drives=$(ls -lah $bkpath | grep -Eo "$vmname\S+" | grep -Ev ".xml")
				for drive in $drives; do
					echo ""
					echo VM $vmname drive $drive is being copied to $dest
					rsync --info=progress2 $drive $dest
				done
		else
			multidrive
		fi;;
    * ) foundname=$(cat $bkpath/*.xml| grep -Eo "name>\S+<"| sed "s/name>//g" | sed "s/<//g");
	    read -p "What is the VM name? (what would you like to name the vm?) [$foundname]: " qvmname;
	    vmname=${qvmname:-$foundname};
	    echo "permanent changes imminent!";
	    sleep 5 ;
	    echo "Renaming system name in xml and for disks...";
	    cp $foundname.xml $foundname.xml.bk;
	    sed -z -i "s/$foundname/$vmname/g" $foundname.xml;
	    newuuid=$(uuidgen);
	    sed -z -i "s|<uuid>.*</uuid>|<uuid>$newuuid</uuid>|g" $foundname.xml;
	    rename s/$foundname/$vmname/g * ;
		destcount=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u| wc -l);
		if [[ $destcount -eq "1" ]] ; then
			dest=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2|\.img"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u);
			read -p "Where would you like to restore disks to [$dest]? " qdest;
			dst=${qdest:-$dest};
			test $dst&&echo 'Path already exists, proceeding'||mkdir -p $dst;
			drives=$(ls -lah $bkpath | grep -Eo "$vmname\S+" | grep -Ev ".xml");
			for drive in $drives; do
				echo " "
				echo VM $vmname drive $drive is being copied to $dst
				rsync --info=progress2 $drive $dst
				echo Updating xml
				sed -z -i "s|$ndest/$vmname|$fdest/$vmname|g" $vmname.xml
			done
		else
			multidrive
		fi;;
esac;
echo ""
echo Importing xml
virsh define --file $bkpath/$vmname.xml
virsh list --all
echo "Done!"
