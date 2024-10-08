#!/usr/bin/env bash
cat <<'EOF'
   _______________                        |*\_/*|________
  |  ___________  |     .-.     .-.      ||_/-\_|______  |
  | |           | |    .****. .****.     | |           | |
  | |   0   0   | |    .*****.*****.     | |   0   0   | |
  | |     -     | |     .*********.      | |     -     | |
  | |   \___/   | |      .*******.       | |   \___/   | |
  | |___     ___| |       .*****.        | |___________| |
  |_____|\_/|_____|        .***.         |_______________|
    _|__|/ \|_|_.............*.............._|________|_
   / ********** \                          / ********** \
 /  ************  \                      /  ************  \
--------------------                    --------------------
EOF
userid=$SUDO_USER
print_green (){
	echo -e "\033[0;32m$1\033[0m"
}
print_yellow (){
	echo -e "\033[0;33m$1\033[0m"
}
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
print_blue (){
	echo -e "\033[0;34m$1\033[0m"
}
print_purple (){
	echo -e "\033[0;35m$1\033[0m"
}
print_purple  "MoreIPsPlease"
echo assumes a /24 address space and modifies the eth0 interface
echo also, resets default to dhcp
echo used for kali during an exercise
[ -z "$1" ] || [ -z "$2" ] && print_yellow "Please provide a startup and iteration number, example:" && echo "./MoreIPsPlease.sh 192.168.1.50 100" && echo "Will populate 192.168.1.50 to 192.168.1.150" && exit
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -n1)
currentIP=$(ip -br a | sed "s/127.0.0.1//g" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n1)
echo IP range to populate
last_Oct=$(echo $1 | awk -F"." '{print $4}')
finial_octet=$(($last_Oct+$2))
first_three_octets=$(echo $1 | cut -d '.' -f 1,2,3)
echo $1 to $first_three_octets.$finial_octet
cat <<'EOF' > ~/MoreIPsPlease.tmp
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
auto eth0
#iface eth0 inet dhcp
iface eth0 inet static
        address sedfailipaddr/24
        gateway sedfailgateway
EOF
sed -i "s/sedfailipaddr/$ipaddr/g" ~/MoreIPsPlease.tmp
sed -i "s/sedfailgateway/$gateway/g" ~/MoreIPsPlease.tmp
i=$last_Oct
while [ $i -le $finial_octet ];
    do
        echo auto eth0:$i >>~/MoreIPsPlease.tmp
        echo iface eth0:$i inet static >>~/MoreIPsPlease.tmp
        echo "       address $first_three_octets.$i/24" >>~/MoreIPsPlease.tmp
        i=$(($i+1))
    done
echo ""
print_blue "The following will replace your /etc/network/interfaces file:"
echo ""
cat ~/MoreIPsPlease.tmp
echo ""
read -t 15 -p "Does the above look correct (y/N)? You have 15 seconds " yn
echo ""
case $yn in
    [yY] )  print_green "Here we go!";
            time=$(date | sed "s/ /_/g");
            bkpath="/home/$userid/interfacesbk";
            print_yellow "Backing up current interface file to $bkpath";
            sleep 2;
            test -d $bkpath&&echo 'Path already created'||mkdir -p $bkpath;
            cp /etc/network/interfaces $bkpath/interfaces_as_of_$time;
            print_yellow "Updating IPs";
            sudo cat ~/MoreIPsPlease.tmp > /etc/network/interfaces;
            sudo service networking restart && ip -br a;
            rm ~/MoreIPsPlease.tmp;
            print_green "[+] Done!";;
    * ) print_yellow "no action taken";
        print_yellow "canceling";
        rm ~/MoreIPsPlease.tmp;
        exit;;
esac
