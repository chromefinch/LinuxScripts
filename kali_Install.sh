#!/usr/bin/env bash
purple='\033[0;35m'
clear='\033[0m'
echo -e ${purple}
cat <<'EOF'
.............. 
            ..,;:ccc,.
          ......''';lxO.
.....''''..........,:ld;
           .';;;:::;,,.x,
      ..'''.            0Xxoc:,.  ...
  ....                ,ONkc;,;cokOdc',.
 .                   OMo           ':ddo.
                    dMc               :OO;
                    0M.                 .:o.
                    ;Wd
                     ;XO,
                       ,d0Odlc;,..
                           ..',;:cdOOd::,.
                                    .:d;.':;.
                                       'd,  .'
                                         ;l   ..
                                          .o
                                            c
                                            .'
                                             .
version 1.6
EOF
echo -e ${clear}
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
read -p "Do you want to roll keys? (y/N) " yn
case $yn in
    [yY] ) echo "ok, here we go!" ;
            #Move old SSH keys into /etc/ssh/old_keys/ dir, issue new SSH keys, verify that the hashes do not match by taking MD5 sums of the old keys and comparing to the MD5 sums of the new keys via a diff. Error checking is incorporated to determine if the old_ssh_signatures file was not created (if not created, this indicates an error in generating the old_keys dir or moving old keys into this new dir). Finally, if something goes wrong and the new keys were not generated (diff does not indicate 'differ' with -q flag) the script will warn the user and require them to manually update ssh keys. If they decline the script will exit.
            test -d /etc/ssh/old_keys&&echo backup folder already exists, deleting...&&sudo rm -rf /etc/ssh/old_keys&&sudo mkdir /etc/ssh/old_keys||sudo mkdir /etc/ssh/old_keys
            test -f old_ssh_signatures.txt&&echo 'Cleaning up previous runs'&&sudo rm -f new_ssh_signatures.txt&&sudo rm -f old_ssh_signatures.txt||echo '...'
            sudo mv -f /etc/ssh/ssh_host* /etc/ssh/old_keys
            sudo dpkg-reconfigure openssh-server
            #Make MD5 sum files for both the old and new ssh keys
            sudo md5sum /etc/ssh/old_keys/ssh_host* | cut -d "/" -f 1 > old_ssh_signatures.txt
            sudo md5sum /etc/ssh/ssh_host* | cut -d "/" -f 1 > new_ssh_signatures.txt
            #Check to make sure the generated old_ssh_signatures.txt file has contents, otherwise exit the script (indicating an error)
            if [[ -z $(grep '[^[:space:]]' old_ssh_signatures.txt) ]] ;then
                #The file is empty
                echo "Error encountered! The old ssh signature file was not successfully generated, exiting...";exit
            else
                #The file has contents
                echo "Old ssh signature file successfully generated."
            fi
            #Compare the old_ssh_signatures to the new_ssh_signatures by diffing with q flag to show if the files differ. If so print output silently with grep -q and evaluate. If the keys were NOT properly generated, prompt for user to manually change keys. Script will exit if user declines to manually upgrade keys.
            diffcheck='diff -q old_ssh_signatures.txt new_ssh_signatures.txt'
            if $diffcheck | grep -q 'differ';
            then
                echo "SUCCESS! The SSH keys have been changed successfully."
            else
                echo "FAILURE! The SSH keys have NOT been changed - please manually upgrade the SSH keys..."
                read -p "Have you manually changed ssh keys (y/n)?" choice
                case "$choice" in
                    y|Y ) echo "User manually updated SSH keys and confirmed...";;
                    n|N ) echo "WARNING! Hardening script NOT COMPLETE. Please manually update the SSH keys in /etc/ssh/ssh_host* using dpkg-reconfigure openssh-server and re-run this script...";exit;;
                    *) echo "Invalid response";;
                esac
            fi;;
    * ) echo "Probably fine";;
esac

set -eu -o pipefail # fail on error and report it, debug all lines

userid=$SUDO_USER
cd /home/$userid
echo $(pwd)

read -p "Do you want some Nvidia? This installs cuda for Hashcat. (y/N) " nvidiainstall

read -p "Do you want to run lynis? (y/N) " lynisrun

cd /home/$userid/Downloads

read -p "Do you want to install Google Chrome? (Y/n) " chromeinstall

read -p "Will you be using xrdp? (Y/n) " xrdpinstall

echo Updating before install... 
echo -e "\n"
sudo apt update  >> /dev/null 2>&1
echo "...doing full-upgrade..."
echo -e "\n"
sudo apt full-upgrade
echo "....doing upgrade...."
echo -e "\n"
sudo apt update && sudo apt upgrade -y
echo ".....doing dist-upgrade....."
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y  >> /dev/null 2>&1
echo  "......doing autoremove......"
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y  >> /dev/null 2>&1
echo  ".......doing autoclean......."
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get autoclean -y  >> /dev/null 2>&1
echo "........Fixing Broken Packages........"
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y  >> /dev/null 2>&1
echo ".........updating searchsploit........."
sudo searchsploit -u && echo -e "\n"
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get update  >> /dev/null 2>&1
echo Updates finished, starting installs
echo you have 3 seconds to proceed ...
echo or
echo hit Ctrl+C to quit
echo -e "\n"
sleep 4

echo adding update alias and terminal candy
term=".$(echo $SHELL | grep -Eo 'bash|zsh')rc"
sudo sed -z -i 's|HISTSIZE=1000\nHISTFILESIZE=2000\n|HISTSIZE=1000000\nHISTFILESIZE=2000000\nexport HISTFILE=~/.bash_history\n|g' /home/$userid/$term
sudo sed -z -i "s|alias ll='ls -alF'\n|alias ll='ls -alFh'\n|g" /home/$userid/$term
sudo sed -z -i "s|alias ll='ls -l'\n|alias ll='ls -alFh'\n|g" /home/$userid/$term
sudo sed -z -i 's|HISTSIZE=1000\nSAVEHIST=2000\n|HISTSIZE=1000000\nSAVEHIST=2000000\n|g' /home/$userid/$term
alreadythere="$(tail -n 1 /home/$userid/$term)"
testv="#alreadydoneflag"
if [ "$alreadythere" = "$testv" ]; then
  echo "bashrc already updated"
else
  cat << EOF >> /home/$userid/$term
fastfetch
alias update="sudo apt update && sudo apt upgrade -y && sudo searchsploit -u"
alias netrset="sudo service networking restart && ip -br a"
#alreadydoneflag
EOF
  sudo chown $userid:$userid /home/$userid/$term
fi

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
sudo rm -f packages.microsoft.gpg


echo installing the must-have pre-requisites like flatpack and the like
while read -r p ; do sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $p  >> /dev/null 2>&1 && echo -e "\n" $p installed... "\n" ; done < <(cat << "EOF"
    bpytop
    flatpak
    code
    xrdp
    libu2f-udev
    spice-vdagent
    remmina
    tmux
    ncdu
    pipx
    git
    seclists
    netexec
    feroxbuster
    gowitness
    sysvinit-utils
    gnome-shell-extension-manager
    gobuster
    hakrawler
    lynis
    net-tools
    mingw-w64
EOF
)

sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y

sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install --or-update flathub md.obsidian.Obsidian -y
sudo flatpak install --or-update flathub org.onlyoffice.desktopeditors -y
sudo flatpak install --or-update flathub com.jetbrains.PyCharm-Community -y
sudo flatpak install --or-update flathub com.github.tchx84.Flatseal -y

echo tmux fun
cd /home/$userid/
test -d /home/$userid/.tmux.bk&&sudo rm -rf /home/$userid/.tmux.bk||echo ...
test -d /home/$userid/.tmux.conf.local.bk&&sudo rm -rf /home/$userid/.tmux.conf.local.bk||echo ....
test -d /home/$userid/.tmux&&sudo mv -f /home/$userid/.tmux /home/$userid/.tmux.bk||echo .....
test -d /home/$userid/.tmux.conf.local&&sudo mv -f /home/$userid/.tmux.conf.local /home/$userid/.tmux.conf.local.bk||echo ......
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local /home/$userid/
sudo chown $userid:$userid /home/$userid/.tmux
sudo chown $userid:$userid /home/$userid/.tmux.conf.local

ff="fastfetch"
fastfile='fastfetch-linux-amd64.deb'
echo downloading $ff...
test -f /home/$userid/Downloads/$fastfile&&echo $ff' already downloaded'||wget 'https://github.com/fastfetch-cli/fastfetch/releases/download/2.15.0/fastfetch-linux-amd64.deb' -P /home/$userid/Downloads
which "$ff" | grep -o "$ff" > /dev/null &&  echo $ff' already installed' || sudo dpkg -i /home/$userid/Downloads/$fastfile

case $xrdpinstall in
        [nN] ) echo "Skipping xrdp configs";;
        * ) echo "Updating xrdp confgs to Gnome Desktop & non standard port";
            #change rdp server port so responder will not conflict, you will still need to enable the service;
            echo xrdp port changed to 3390;
            sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini;
            sudo apt install -y kali-desktop-gnome;
            echo "gnome-session" | tee /home/$userid/.xsession;;
esac

#fixes xrdp color prompt
cat << EOF > /etc/polkit-1/rules.d/02-allow-colord.rules
polkit.addRule(function(action, subject) {
if ((action.id == "org.freedesktop.color-manager.create-device" ||
action.id == "org.freedesktop.color-manager.create-profile" ||
action.id == "org.freedesktop.color-manager.delete-device" ||
action.id == "org.freedesktop.color-manager.delete-profile" ||
action.id == "org.freedesktop.color-manager.modify-device" ||
action.id == "org.freedesktop.color-manager.modify-profile") &&
subject.isInGroup("{users}")) {
return polkit.Result.YES;
}
});
EOF

case $nvidiainstall in
    [yY] ) echo ok, installing cuda;
        sudo apt install -y linux-headers-amd64;
        sudo apt install -y nvidia-driver nvidia-cuda-toolkit;;
    * ) echo Skipping Nvidia Cuda install;;
esac

case $lynisrun in
    [yY] ) echo "Running lynis. Please wait...forever...";
        sudo lynis audit system > /home/$userid/lynis_log.txt;
        sudo netstat -tulpn > /home/$userid/open_ports_log.txt;
	sudo gzip -d /usr/share/wordlists/rockyou.txt.gz;;
    * ) echo "Skipping lynis run";;
esac

case $chromeinstall in
        [nN] ) echo "Skipping Google Chrome install";;
        * ) echo cd /home/$userid/Downloads;
            chromedefault='google-chrome-stable_current_amd64.deb';
            #read -p "Enter desired version of Google Chrome [$chromedefault]:" chromev;
            chromefile=${chromev:-$chromedefault};
            echo downloading $chromefile...;
            test -f /home/$userid/Downloads/$chromefile&&echo 'Chrome already downloaded'||wget https://dl.google.com/linux/direct/$chromefile -P /home/$userid/Downloads;
            gc="google-chrome";
            which "$gc" | grep -o "$gc" > /dev/null &&  echo $gc' already installed' || sudo dpkg -i /home/$userid/Downloads/$chromefile;;
esac
### Hostname randomizer  - 12/17/2024 ###

old=$(cat /etc/hostname)
new=$(tr -dc 'A-Z0-9' < /dev/urandom | head -c12)
sed -i "s/$old/$new/g" /etc/hosts
sed -i "s/$old/$new/g" /etc/hostname
hostname "$new"

### End Hostname randomizer ###

read -p "Would you like to restart now? (y/N) " yn
case $yn in 
    [yY] )sudo reboot;
        break;;
    * ) echo "you should restart soonest";
        exit;;
esac
