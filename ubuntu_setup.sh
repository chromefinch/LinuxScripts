#!/usr/bin/env bash
cat <<'EOF'
        _
     ---(_)
 _/  ---  \\
(_) |   |
  \\  --- _/
     ---(_)
version 1.6
Consider the following gnome extensions!
App Icons Taskbar
https://extensions.gnome.org/extension/4944/app-icons-taskbar/
Vitals
https://extensions.gnome.org/extension/1460/vitals/
EOF
set -eu -o pipefail # fail on error and report it, debug all lines
print_red (){
	echo -e "\033[0;31m$1\033[0m"
}
if [[ $EUID -ne 0 ]]; then
   print_red "This script must be run as root"
   exit 1
fi
userid=$SUDO_USER
cd /home/$userid
echo $(pwd)
vmwarefile='VMware-Workstation-Full-17.5.2-23775571.x86_64.bundle'
vmwareE='VMware-Workstation-Full-17.5.2-23775571.x86_64.bundle'
vmwareversion='17.5.2'
vmwareFIXversion='17.5.0'
read -p "Do you want to install Signal? (Y/n) " yn
case $yn in
    [nN] ) echo "that's weird...";;
    * ) echo adding signal repos;
        wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg;
        cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null;
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' |\
        sudo tee /etc/apt/sources.list.d/signal-xenial.list;;
esac

read -p "Do you have a fingerprint reader? (y/N) " yn
case $yn in
    [yY] ) echo "ok, check Fingerprint auth for in terminal fingerprints" ;
        sleep 3;
        sudo pam-auth-update;;
    * ) echo "I do and it's great...";;
esac

read -p "Do you want to install Google Chrome? (Y/n) " chromeinstall

read -p "Do you want to create another user? (y/N) " seconduser

read -p "Do you want some Nvidia? This installs cuda for Hashcat. (y/N) " nvidiainstall

read -p "Do you want some VMware? (y/N) " vmwareinstall

echo -e "\n"
#echo adding full Graphics Driver repo, hit enter to apply...
#sudo add-apt-repository ppa:graphics-drivers/ppa >> /dev/null 2>&1

#No license no sublime use kate instead
#echo grabbing sublime text repo info...
#wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
#echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

echo Updating system
echo you have 5 seconds to proceed ...
echo or
echo hit Ctrl+C to quit
echo -e "\n"
sleep 6
sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
echo Updating before install... 
echo -e "\n"
sudo apt-get update >> /dev/null 2>&1
echo "...doing upgrade..."
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> /dev/null 2>&1
echo "....doing dist-upgrade...."
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y >> /dev/null 2>&1
echo  ".....doing autoremove....."
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >> /dev/null 2>&1
echo  "......doing autoclean......"
echo -e "\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get autoclean -y >> /dev/null 2>&1
echo "......updating snap......"
echo -e "\n"
sudo snap refresh >> /dev/null 2>&1
echo -e "\n"

echo Updates finished, system changes imminent
echo you have 5 seconds to proceed ...
echo or
echo hit Ctrl+C to quit
echo -e "\n"
sleep 6

sudo snap install pycharm-community --classic
sudo snap install obsidian --classic
sudo snap install code --classic
sudo snap install seclists
echo -e "\n"

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
alias update="sudo apt update && sudo apt upgrade -y && sudo snap refresh"
alias k8="kate"
#alreadydoneflag
EOF
sudo chown $userid:$userid /home/$userid/$term
fi
echo -e "\n"
echo installing the must-have pre-requisites
while read -r p ; do sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $p >> /dev/null 2>&1 && echo -e "\n" $p installed... "\n" ; done < <(cat << "EOF"
    bpytop
    python3
    fastfetch
    kate
    curl
    gcc
    fzf
    clamav
    tmux
    ncdu
    git
    fzf
    hashcat
    gufw
    signal-desktop
    flatpak
    make
    qemu-kvm
    libvirt-daemon-system
    libvirt-clients
    bridge-utils
    virtinst
    virt-manager
    net-tools
    gnome-shell-extension-manager
    sysvinit-utils
    wireshark
    rename
EOF
)
#lxc configs
#sudo systemctl is-active libvirtd
echo enabeling pcie passthrough
sudo sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on"|g' /etc/default/grub
sudo update-grub >> /dev/null 2>&1

sudo usermod -aG kvm $userid
sudo usermod -aG libvirt $userid

sudo apt install gnome-software-plugin-flatpak -y
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install --or-update flathub org.onlyoffice.desktopeditors -y
sudo flatpak install --or-update flathub com.github.tchx84.Flatseal -y
flatpak install --or-update flathub org.keepassxc.KeePassXC -y

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

case $seconduser in
    [yY] ) echo creating another user and shared vms folder in root along with vms group;
        grp="vms";
        ls / | grep -o "$grp" > /dev/null &&  echo 'folder '$grp' already created' || sudo mkdir /$grp;
        groups $userid | grep -o "$grp" > /dev/null &&  echo 'group '$grp' already created' || sudo groupadd $grp && sudo adduser $userid $grp;
        cat /etc/passwd | grep -o "another" > /dev/null && echo 'another already created...' || sudo useradd -m -s /usr/bin/bash -G $grp another;
        #openssl passwd -1 'enterPasswordHere'
        echo 'another:enterhashhere' | chpasswd -e;
        sudo chown  root:vms /vms;
        sudo chmod 2771 /vms;;
    * ) echo Skipping another user creation;;
esac

case $nvidiainstall in
    [yY] ) echo Installing Cuda hashkiddy;
        sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-cuda-toolkit;;
    * ) echo Skipping Nvidia Cuda install;;
esac

case $vmwareinstall in
    [yY] ) echo Lets install VMware Workstation $vmwareversion
        echo downloading $vmwareE...;
        test -f /home/$userid/Downloads/$vmwareE&&echo 'VMware already downloaded' || echo please download $vmwarefile and put it in /home/$userid/Downloads;
        echo getting fixes;
        test -f /home/$userid/Downloads/workstation-$vmwareFIXversion.tar.gz&&echo 'VMware fix already downloaded' || wget https://github.com/mkubecek/vmware-host-modules/archive/workstation-$vmwareFIXversion.tar.gz -P /home/$userid/Downloads
        cd /home/$userid/Downloads
        tar -xzf workstation-$vmwareFIXversion.tar.gz;
        cd vmware-host-modules-workstation-$vmwareFIXversion;
        tar -cf vmmon.tar vmmon-only;
        tar -cf vmnet.tar vmnet-only;
        sudo chown $userid:$userid /home/$userid/Downloads/*;
        sudo bash /home/$userid/Downloads/$vmwareE --eulas-agreed --console;
        cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/;
        sudo vmware-modconfig --console --install-all;
        echo "if there are VMware service failures (vmmon vmnet) or anyother VMware issues, check if SecureBoot is enabled and visit; https://www.centennialsoftwaresolutions.com/post/ubuntu-20-04-3-lts-and-vmware-issues";
        echo this is dumb;
        vmware --version;;
    * ) echo Skipping VMware Workstation install. Linux KVM FTW...;;
esac
read -p "Would you like to restart now? (y/N) " yn
case $yn in 
    [yY] )sudo reboot;
        break;;
    * ) echo "you should restart soonest";
        exit;;
esac
