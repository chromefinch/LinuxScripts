#!/usr/bin/env bash
purple='\033[0;35m'
clear='\033[0m'
echo -e ${purple}
cat <<'EOF'
     .
   .:;:.
 .:;;;;;:.
   ;;;;;
   ;;;;;
   ;;;;;
   ;;;;;
   ;:;;;
   : ;;;
     ;:;
   . :.;
     . :
   .   .

      .

version 1
EOF
echo -e ${clear}
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
echo "This VM restore script assumes you previously backed up with kvmbk.sh and that you are using .qcow2 or .img disks"
echo ""
echo ""
userid=$SUDO_USER
echo "current dir"
echo ""
pwd
ls -1
echo ""
multidrive () {
	echo Multiple drive paths in xml;
	echo reading xml drives...;
	drives=$(cat $foundname.xml| grep -Eo "'.*\.qcow2|\.img"| sed "s/'//g");
	echo $drives;
	for drive in $drives; do
		ndest=$(echo $drive| grep -Eo ".*\/");
		ndrive=${drive##*/}
		newdrive=$(echo $ndrive| sed -z "s/$foundname/$vmname/g")
		[ "$ndrive" == "$newdrive" ] && newdrive=$(echo $vmname$ndrive)
		echo ""
		read -p "please enter a drive path for $ndrive [$ndest]: " qdest
		fdest=${qdest:-$ndest}
		echo VM $vmname drive $ndrive.panic is being copied to $fdest,
		echo will rename from $ndrive.panic to $newdrive when complete.
		test $fdest&&echo 'Path already exists, proceeding...'||mkdir -p $fdest
		rsync --info=progress2 -b --suffix=".panic" $ndrive $fdest
		echo renaming drive from $ndrive.panic to $newdrive
		sudo mv $fdest$ndrive.panic $fdest$newdrive
		echo Updating xml with path info $ndest$ndrive to $fdest$newdrive
		sed -i "s|$ndest$ndrive|$fdest$newdrive|g" $vmname.xml
	done;
}

sleep 2
read -p "Where are backup files? (absolute path only) " bkpath
echo "Listing found backup files:"
ls -1 $bkpath
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
	    read -p "What would you like to name the vm? Source VM name is [$foundname]: " qvmname;
	    vmname=${qvmname:-$foundname};
	    echo "If the VM name matches an existing VM, it will be overwritten";
	    sleep 1 ;
	    echo "Permanent changes imminent!";
	    sleep 1 ;
	    echo "Backing up & copying xml for new system config...";
	    cp $foundname.xml $foundname.xml.bk;
		cp $foundname.xml $vmname.xml;
		sleep 1;
		echo updating $vmname.xml;
	    sed -z -i "s|<name>$foundname</name>|<name>$vmname</name>|g" $vmname.xml;
	    sed -z -i "s|nvram/$foundname|nvram/$vmname|g" $vmname.xml;
	    echo generating a new uuid for vm, this step does not change the MAC address, watch for dups if nessary.
	    echo " "
	    newuuid=$(uuidgen);
	    sed -z -i "s|<uuid>.*</uuid>|<uuid>$newuuid</uuid>|g" $vmname.xml;
		destcount=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u| wc -l);
		if [[ $destcount -eq "1" ]] ; then
			dest=$(cat $vmname.xml| grep -Eo "'\S+\.qcow2|\.img"| sed "s/'//g" | grep -Eo "\S+\/" | sort -u);
			read -p "Where would you like to restore disks to [$dest]? " qdest;
			dst=${qdest:-$dest};
			test $dst&&echo 'Path already exists, proceeding'||mkdir -p $dst;
			drives=$(ls -lah $bkpath | grep -Eo "$foundname\S+" | grep -Ev ".xml");
			for drive in $drives; do
				newdrive=$(echo $drive| sed -z "s/$foundname/$vmname/g")
				[ "$drive" "$newdrive" ] && newdrive=$(echo $vmname$drive)
				echo VM $vmname drive $drive.panic is being copied to $dst,
				echo will rename from $drive.panic to $newdrive when complete.
				rsync --info=progress2 -b --suffix=".panic" $drive $dst
				echo renaming drive from $drive.panic to $newdrive
				sudo mv $dst$drive.panic $dst$newdrive
				echo Updating xml with path info
				sed -i "s|$dest$drive|$dst$newdrive|g" $vmname.xml
			done
		else
			multidrive
		fi;;
esac;
echo ""
echo Importing xml
virsh define --file $bkpath/$vmname.xml
virsh list --all
sudo rm $vmname.xml
sudo mv $foundname.xml.bk $foundname.xml
echo "Done!"
