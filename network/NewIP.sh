#!/usr/bin/env bash
red='\033[0;31m'
clear='\033[0m'
echo -e ${red}
cat <<'EOF'
                                        :::
                                    .*@@@@@@@=
                                 .:*@@*.   :%@@+:
                             #@@@@@@+.       :%@@@@@@=
                             @@-..               ..*@#
                             @@:        @%-        *@#
                             @@=    ** :@@@+  =#   *@*
                             *@%  -@@@.+@%@@-.@@- :@@:
                             :@@-.@@@@%@@:=@**@@% *@#
                              +@%=@@.*@%: +@@@*@%=@@: -%%%%-   -%%%%%%%
                               +@@@%    ::::. =@@@@: .%@@@@=   =@@@@@@@
                                =@@@-##+@% +#:@@@%:
                                 .%@@%@@@@@@:#@@+
                             @@@=   %@@@@@@@@@=  .#*  *@@@@@@@@@:
                             @@@@@=.  -#@@@+:  :#@@*  *@@@@@@@@@:
                             *******=        :*****=  =*********.
                                   ..........   .........    .........
                                  .@@@@@@@@@@: :@@@@@@@@@#  :@@@@@@@@@*
                                  .@@@@@@@@@@: :@@@@@@@@@#  :@@@@@@@@@*
                                   ==========  .=========-  .=========:

                             @@@@@@@@@%. =@@@@@@@@@*  *@@@@@@@@@:
                             @@@@@@@@@%. =@@@@@@@@@*  *@@@@@@@@@:
                             ---------:. .---------:  :---------.
EOF
echo -e ${clear}
userid=$SUDO_USER
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
print_purple (){
	echo -e "\033[0;35m$1\033[0m"
}
print_green (){
	echo -e "\033[0;32m$1\033[0m"
}
print_yellow (){
	echo -e "\033[0;33m$1\033[0m"
}
echo "                                                        NewIP"
print_purple "assumes a /24 address space and modifies the eth0 interface"
print_purple "used for kali during an exercise"
echo ""
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -n1)
currentIP=$(ip -br a | sed "s/127.0.0.1//g" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n1)
last_Oct=$(echo $currentIP | awk -F"." '{print $4}')
burned=$(cat /etc/network/interfaces | grep -Eo 'burned [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
bip=$(echo -e "$burned" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
double=$(echo -e "$bip"| tr '\n' '||' | sed 's/|$//' | sed 's/^|//')
ipz=$(ip -br a | sed "s/127.0.0.1//g" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
echo -e "$ipz"| sed -E "s/($double)//g" | sed '/^$/d'
echo -e ${red}"$burned"${clear}
read -p "what IP would you like to make the new default? " ipaddr
ipaddr_last_Oct=$(echo $ipaddr | awk -F"." '{print $4}')
cat <<'EOF' > ~/NewIP.tmp
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
cat /etc/network/interfaces | grep "eth0:" -A 2 >> ~/NewIP.tmp
echo ""
print_yellow "changing ip to $ipaddr"
print_yellow "with a gateway of $gateway"
echo ""
sed -E -i "s/.*eth0:$ipaddr_last_Oct.*//g" ~/NewIP.tmp
sed -E -i "s/.*$ipaddr.*//g" ~/NewIP.tmp
sed -i "s/sedfailipaddr/$ipaddr/g" ~/NewIP.tmp
sed -i "s/sedfailgateway/$gateway/g" ~/NewIP.tmp
sed -i '/^$/d' ~/NewIP.tmp
sed -E -i 's|source /etc/network/interfaces.d/\*|\nsource /etc/network/interfaces.d/\*\n|g' ~/NewIP.tmp
echo \# burned $currentIP >>~/NewIP.tmp
echo auto eth0:$last_Oct >>~/NewIP.tmp
echo iface eth0:$last_Oct inet static >>~/NewIP.tmp
echo "       address $currentIP/24" >>~/NewIP.tmp
cat ~/NewIP.tmp
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
            sudo cat ~/NewIP.tmp > /etc/network/interfaces;
            sudo ifdown eth0 >> /dev/null 2>&1;
            sudo service networking restart;
            sudo ifup eth0;
            sudo service networking restart;
            sleep 3;
            sudo service networking restart && ip -br a;
            rm ~/NewIP.tmp;
            print_green "[+] Done!";;
    * ) print_yellow "no action taken";
        print_yellow "canceling";
        rm ~/NewIP.tmp;
        exit;;
esac
