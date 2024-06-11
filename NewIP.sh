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
echo "                                                        NewIP"
print_purple "assumes a /24 address space and modifies the eth0 interface"
print_purple "used for kali during an exercise"
echo ""
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
gateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
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
echo changing ip to $ipaddr
echo with a gateway of $gateway
echo this is your only check...
sleep 1
echo 3
sleep 1
echo 2
sleep 1
echo 1
sleep 1
echo blastoff!
sed -E -i "s|.*iface eth0 inet dhcp|#iface eth0 inet dhcp\niface eth0 inet static\n       address $ipaddr\/24\n       gateway $gateway|g" /etc/network/interfaces
sed -E -i "s/.*eth0:$ipaddr_last_Oct.*//g" /etc/network/interfaces
sed -E -i "s/.*$ipaddr.*//g" /etc/network/interfaces
sed -i '/^$/d' /etc/network/interfaces
sed -E -i 's|source /etc/network/interfaces.d/\*|\nsource /etc/network/interfaces.d/\*\n|g' /etc/network/interfaces
echo \# burned $currentIP >>/etc/network/interfaces
echo auto eth0:$last_Oct >>/etc/network/interfaces
echo iface eth0:$last_Oct inet static >>/etc/network/interfaces
echo "       address $currentIP/24" >>/etc/network/interfaces
sudo service networking restart && ip -br a
