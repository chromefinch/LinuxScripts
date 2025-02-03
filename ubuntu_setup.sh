#!/usr/bin/env bash
ORNG=$(echo "\033[38;5;202m")
CL=$(echo "\033[m")
function header_info {
    clear
    echo -e "$ORNG"
cat <<'EOF' 
                                          GGGGGGGGGGG                                          
                                   GGGGGGGGGGGGGGGGGGGGGGGGG                                   
                             GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                             
                          GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                          
                       GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                       
                     GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                     
                  GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                  
                 GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGí    íÞGGGGGGGGGGGGG                
               GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGí        {GGGGGGGGGGGGG               
             GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGÏ          zGGGGGGGGGGGGGG             
            GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGÞÇ6ÏÏzÏÏ6ÇÞGGGí          íGGGGGGGGGGGGGGG            
           GGGGGGGGGGGGGGGGGGGGGGGGGGüí›              6GÇ          6GGGGGGGGGGGGGGGG           
          GGGGGGGGGGGGGGGGGGGGGGGGGGG›                 ÇGG{      —GGGGGGGGGGGGGGGGGGG          
         GGGGGGGGGGGGGGGGGGGGGG6— íGGGí                 íGGGÞÇÇÇGGGGGGGGGGGGGGGGGGGGGG         
        GGGGGGGGGGGGGGGGGGGGGÞ›    íGGG{                   {6ÇÇ6zÇGGGGGGGGGGGGGGGGGGGGG        
       GGGGGGGGGGGGGGGGGGGGG{       íGGGzÏÇGGGGGGGGGÇÏ{           {GGGGGGGGGGGGGGGGGGGGG       
      GGGGGGGGGGGGGGGGGGGGÞ›         —GGGGGGGGGGGGGGGGGGÇ›          ÇGGGGGGGGGGGGGGGGGGGG      
      GGGGGGGGGGGGGGGGGGGÇ         íÞGGGGGGGGGGGGGGGGGGGGGÞí         6GGGGGGGGGGGGGGGGGGG      
      GGGGGGGGGGGGGGGGGGÇ         ÇGGGGGGGGGGGGGGGGGGGGGGGGGÞ         6GGGGGGGGGGGGGGGGGG      
     GGGGGGGGGGGGGGGGGGG{       ›ÞGGGGGGGGGGGGGGGGGGGGGGGGGGGÞ—       —GGGGGGGGGGGGGGGGGGG     
     GGGGGGGGGGGGGGGGGGÇ        ÇGGGGGGGGGGGGGGGGGGGGGGGGGGGGGÞ        üGGGGGGGGGGGGGGGGGG     
    GGGGGGGGGGÞí     zÞGÇ›     üGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGü       ›GGGGGGGGGGGGGGGGGGG    
    GGGGGGGGGz         ÏGG     GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG        ÞGGGGGGGGGGGGGGGGGG    
    GGGGGGGGÇ           ÇGz   {GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG    
    GGGGGGGGÇ           ÇGÏ   {GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG    
    GGGGGGGGGz         ÏGG     GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG›       ÞGGGGGGGGGGGGGGGGGG    
    GGGGGGGGGGÇí     íÞGÞ—     üGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGü       ›GGGGGGGGGGGGGGGGGGG    
     GGGGGGGGGGGGGGGGGG6        ÞGGGGGGGGGGGGGGGGGGGGGGGGGGGGGÞ        üGGGGGGGGGGGGGGGGGG     
     GGGGGGGGGGGGGGGGGGG{       ›ÞGGGGGGGGGGGGGGGGGGGGGGGGGGGÞ—       —GGGGGGGGGGGGGGGGGGG     
      GGGGGGGGGGGGGGGGGG6         ÞGGGGGGGGGGGGGGGGGGGGGGGGGÞ         6GGGGGGGGGGGGGGGGGG      
      GGGGGGGGGGGGGGGGGGGÇ         íÞGGGGGGGGGGGGGGGGGGGGGÞí         6GGGGGGGGGGGGGGGGGGG      
      GGGGGGGGGGGGGGGGGGGGÞ›         {GGGGGGGGGGGGGGGGGGÇ›          ÇGGGGGGGGGGGGGGGGGGGG      
       GGGGGGGGGGGGGGGGGGGGG{       {GGGÏüÇGGGGGGGGGÇü{           —ÞGGGGGGGGGGGGGGGGGGGG       
        GGGGGGGGGGGGGGGGGGGGGÇ›    íGGGí                   {üÇÇüzÇGGGGGGGGGGGGGGGGGGGGG        
         GGGGGGGGGGGGGGGGGGGGGG6› íGGGí                 íGGGÞÇÇÞGGGGGGGGGGGGGGGGGGGGGG         
          GGGGGGGGGGGGGGGGGGGGGGGGGGG—                 6GGí      {GGGGGGGGGGGGGGGGGGGG         
           GGGGGGGGGGGGGGGGGGGGGGGGGGü{›              6GÇ          6GGGGGGGGGGGGGGGG           
            GGGGGGGGGGGGGGGGGGGGGGGGGGGGGÞÇ6üÏzzzÏü6ÇÞGGz          íGGGGGGGGGGGGGGG            
             GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGz          zGGGGGGGGGGGGGG             
               GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGí        —GGGGGGGGGGGGG               
                GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGÞí    {ÞGGGGGGGGGGGGG                
                  GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                  
                     GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                     
                       GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                       
                          GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                          
                             GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG                             
                                  GGGGGGGGGGGGGGGGGGGGGGGGGGG                                  
                                          GGGGGGGGGGG                                          
EOF
echo -e "$CL"
echo "version 2.0"
}

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
silent() { "$@" >/dev/null 2>&1; }
set -e
header_info
echo "Loading..."
function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

set -eu -o pipefail # fail on error and report it, debug all lines
print_red (){
echo -e "\033[0;31m$1\033[0m"
}   
if [[ $EUID -ne 0 ]]; then
    print_red "This script must be run as root"
    exit 1
fi
userid=$SUDO_USER

install() {
    STD="silent"
    header_info
    msg_info "Launching no touch in - 5"
    sleep 1
    msg_info "4"
    sleep 1
    msg_info "3"
    sleep 1
    msg_info "2"
    sleep 1
    msg_info "1"
    sleep 1
    msg_ok "Launched"

    signalRepo
    fastFetchRepo
    letsUpdate
    apps
    flatHub
    chromeInstall
    lxcInstall
    nvidiaInstall
    fastFetchInstall
    tmuxStuff
    secondUser
    allDone
}

signalRepo() {
      msg_info "Setting up Signal repository"
  #wget -q https://repo.netdata.cloud/repos/repoconfig/debian/bookworm/netdata-repo_2-2+debian12_all.deb
  #$STD dpkg -i netdata-repo_2-2+debian12_all.deb
  #rm -rf netdata-repo_2-2+debian12_all.deb
    wget -q -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg 
    cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | $STD sudo tee /etc/apt/sources.list.d/signal-xenial.list
  msg_ok "Set up Signal repository"
}

fastFetchRepo() {
   msg_info "Setting up FastFetch repository"
  #wget -q https://repo.netdata.cloud/repos/repoconfig/debian/bookworm/netdata-repo_2-2+debian12_all.deb
  #$STD dpkg -i netdata-repo_2-2+debian12_all.deb
  #rm -rf netdata-repo_2-2+debian12_all.deb
  $STD sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
  msg_ok "Set up FastFetch repository"
}

letsUpdate() {
    msg_info "Updating before install"
    $STD sudo apt-get update
    msg_ok "apt update done"
    msg_info "doing upgrade"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    msg_ok "apt upgrade done"
    msg_info "doing dist-upgrade"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    msg_ok "dist-upgrade done"
    msg_info  "doing apt autoremove"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
    msg_ok "apt autoremove done"
    msg_info  "doing autoclean"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt-get autoclean -y
    msg_ok "apt autoclean done"
    msg_info "updating snap"
    $STD sudo snap refresh
    msg_ok "snap updated"
    msg_ok "Updates done"
}

apps() {
    while read -r p ; do $STD sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $p && msg_ok "$p installed" ; done < <(cat << "EOF"
    bpytop
    python3
    fastfetch
    curl
    gcc
    tree
    clamav
    tmux
    ncdu
    git
    fzf
    hashcat
    feroxbuster
    gufw
    signal-desktop
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
    while read -r p ; do $STD sudo snap install $p && msg_ok "$p installed" ; done < <(cat << "EOF"
    pycharm-community --classic
    obsidian --classic
    code --classic
    seclists
    tree
EOF
)
}

flatHub() {
    msg_info "Installing flathub"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt install flatpak -y
    $STD sudo DEBIAN_FRONTEND=noninteractive apt install gnome-software-plugin-flatpak -y
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    msg_ok "Flathub installed"
    while read -r p ; do $STD sudo flatpak install --or-update flathub $p -y --noninteractive && msg_ok "flathub $p installed" ; done < <(cat << "EOF"
        org.onlyoffice.desktopeditors
        com.github.tchx84.Flatseal
        org.keepassxc.KeePassXC
EOF
)
}

lxcInstall() {
#lxc configs
#sudo systemctl is-active libvirtd
msg_info "enabeling pcie passthrough"
sudo sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on"|g' /etc/default/grub
$STD sudo update-grub
sudo usermod -aG kvm $userid
sudo usermod -aG libvirt $userid
msg_ok "pcie passthrough enabled"
}

gnomeExtFail() {
  # This Function does not work which makes me sad and mad, but mostly sad
    msg_info "adding gnome extension app-icons-taskbar"
    urls=(
      'https://extensions.gnome.org/extension/4944/app-icons-taskbar/'
    )

    # Loop through each URL
    for url in "${urls[@]}"; do
      echo "url = ${url}"
      # get package metadata
      id=$(echo "${url}" | cut --delimiter=/ --fields=5)
      url_pkg_metadata="https://extensions.gnome.org/extension-info/?pk=${id}"
      # Extract data for each extension
      uuid=$(curl -s "$url_pkg_metadata" | jq -r '.uuid' | tr -d '@')
      latest_extension_version=$(curl -s "$url_pkg_metadata" | jq -r '.shell_version_map | to_entries | max_by(.value.version) | .value.version')
      latest_shell_version="46"

      # get  package
      filename="${uuid}.v${latest_extension_version}.shell-extension.zip"
      url_pkg="https://extensions.gnome.org/extension-data/${filename}"
      wget -q -P /tmp "${url_pkg}"
      # install package
      gnome-extensions install "/tmp/${filename}" --force

      # Print the results
      echo "For URL: $url"
      echo "UUID: $uuid"
      echo "Latest extension version: $latest_extension_version"
      echo "Latest shell version: $latest_shell_version"
      echo "--------------------------------------"
    done
    msg_ok "gnome extension app-icons-taskbar installed"
}

nvidiaInstall() {
    msg_info "Assessing Nvidia HW status"
    if ! lspci | grep -q "VGA compatible controller: NVIDIA"; then
        msg_ok "No Nvidia card found, skipping"
    else
        $STD sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-cuda-toolkit
        msg_ok "Nvidia cuda toolkit installed"
    fi
}

fastFetchInstall() {
    msg_info "Assessing Fingerprint HW status"
    if ! lsusb | grep -q "Fingerprint"; then
        msg_ok "No fingerprint found, skipping"
    else
        $STD sudo pam-auth-update --enable fprintd
        msg_ok "Fingerprint auth enabled"
    fi
}

chromeInstall() {
  msg_info "installing Google Chrome"
  cd /home/$userid/Downloads
  chromedefault='google-chrome-stable_current_amd64.deb'
  #read -p "Enter desired version of Google Chrome [$chromedefault]:" chromev;
  chromefile=${chromev:-$chromedefault}
  #echo downloading $chromefile...
  test -f /home/$userid/Downloads/$chromefile&&msg_ok 'Chrome already downloaded'||wget -q https://dl.google.com/linux/direct/$chromefile -P /home/$userid/Downloads
  gc="google-chrome"
  which "$gc" | grep -o "$gc" > /dev/null &&  msg_ok $gc' already installed' || $STD sudo dpkg -i /home/$userid/Downloads/$chromefile && msg_ok "Google Chrome installed"

}

tmuxStuff() {
  msg_info "tmux fun"
  cd /home/$userid/
  test -d /home/$userid/.tmux.bk&&sudo rm -rf /home/$userid/.tmux.bk
  test -d /home/$userid/.tmux.conf.local.bk&&sudo rm -rf /home/$userid/.tmux.conf.local.bk
  test -d /home/$userid/.tmux&&sudo mv -f /home/$userid/.tmux /home/$userid/.tmux.bk
  test -d /home/$userid/.tmux.conf.local&&sudo mv -f /home/$userid/.tmux.conf.local /home/$userid/.tmux.conf.local.bk
  git clone -q https://github.com/gpakosz/.tmux.git
  ln -s -f .tmux/.tmux.conf
  cp .tmux/.tmux.conf.local /home/$userid/
  sudo chown $userid:$userid /home/$userid/.tmux
  sudo chown $userid:$userid /home/$userid/.tmux.conf.local
  msg_ok "tmux fun installed"

  msg_info "adding update alias and terminal candy"
  term=".$(echo $SHELL | grep -Eo 'bash|zsh')rc"
  sudo sed -z -i 's|HISTSIZE=1000\nHISTFILESIZE=2000\n|HISTSIZE=1000000\nHISTFILESIZE=2000000\nexport HISTFILE=~/.bash_history\n|g' /home/$userid/$term
  sudo sed -z -i "s|alias ll='ls -alF'\n|alias ll='ls -alFh'\n|g" /home/$userid/$term
  sudo sed -z -i "s|alias ll='ls -l'\n|alias ll='ls -alFh'\n|g" /home/$userid/$term
  sudo sed -z -i 's|HISTSIZE=1000\nSAVEHIST=2000\n|HISTSIZE=1000000\nSAVEHIST=2000000\n|g' /home/$userid/$term
  alreadythere="$(tail -n 1 /home/$userid/$term)"
  testv="#alreadydoneflag"
  if [ "$alreadythere" = "$testv" ]; then
    msg_ok "bashrc already updated"
  else
    cat << EOF >> /home/$userid/$term
fastfetch
alias update="sudo apt update && sudo apt upgrade -y && sudo snap refresh"
#alreadydoneflag
EOF
    sudo chown $userid:$userid /home/$userid/$term
    msg_ok "added update alias and terminal candy"
  fi
}

secondUser() {
  read -p "Do you want to create another user? (y/N) " seconduser
  case $seconduser in
    [yY]) read -p "Please enter their user name: " another
        msg_info "Creating $another user and shared vms folder in root along with vms group"
        grp="vms"
        ls / | grep -o "$grp" > /dev/null &&  msg_ok "folder $grp already created" || $STD sudo mkdir /$grp
        groups $userid | grep -o "$grp" > /dev/null &&  msg_ok "group $grp already created" || $STD sudo groupadd $grp && $STD sudo adduser $userid $grp
        cat /etc/passwd | grep -o "$another" > /dev/null && msg_ok "$another already created..." && allDone || $STD sudo useradd -m -s /usr/bin/bash -G $grp $another
        read -s -p "Please enter their password: " enterPasswordHere
        enterhashhere=$(openssl passwd -1 "$enterPasswordHere")
        echo "$another:$enterhashhere" | chpasswd -e
        enterhashhere="just a really fantastic password"
        sudo chown  root:vms /vms
        sudo chmod 2771 /vms
      ;;
    *) msg_ok "Skipping another user creation"
      ;;
esac
}

allDone() {
  msg_ok "Ok, I think we're done!\n"
  read -p "Would you like to restart now? (y/N) " yn
  case $yn in 
    [yY]) echo "install app icons taskbar by visiting the following link: https://extensions.gnome.org/extension/4944/app-icons-taskbar/"
        sudo reboot
        return 1
        ;;
    *) msg_info "you should restart soonest"
        echo " install app icons taskbar by visiting the following link: https://extensions.gnome.org/extension/4944/app-icons-taskbar/"
        exit
        ;;
  esac
}

custom() {
  header_info
  read -r -p "Verbose mode? <y/N> " prompt
  if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  STD=""
  else
  STD="silent"
  fi
  header_info

    signalRepo
    fastFetchRepo
    letsUpdate
    apps
    read -p "Do you want to install Google Chrome? (Y/n) " chromeq
        case $chromeq in
                [nN]) msg_ok "Skipping Google Chrome install";;
                *) chromeInstall;;
        esac
    read -p "Do you want to enable pcie passthrough? (Y/n) " kvmq
        case $kvmq in
                [nN]) msg_ok "Skipping pcie passthrough";;
                *) lxcInstall;;
        esac
    read -p "Do you want some Nvidia? This installs cuda for Hashcat. (Y/n) " nvidiaq
        case $nvidiaq in
                [nN]) msg_ok "Skipping Nvidia install";;
                *) nvidiaInstall;;
        esac
    read -p "Do you want to install Flathub goodies?  (Y/n) " flatq
        case $flatq in
                [nN]) msg_ok "Skipping Flathub goodies install";;
                *) flatHub;;
        esac
    fastFetchInstall
    tmuxStuff
    secondUser
    allDone
}


if ! hostnamectl | grep -Eq "Operating System: Ubuntu 24\.[\.0-9]{2,}"; then
  echo -e "This version of Linux is not supported"
  echo -e "Requires Ubuntu 24.04 or higher"
  echo -e "Exiting..."
  sleep 2
  exit
fi

OPTIONS=(Full "Install (Google Chrome, Signal, nvidia, etc)" \
         Custom "Install")

CHOICE=$(whiptail --backtitle "Ubuntu Helper Scripts" --title "Install Packages" --menu "Select an option:" 10 58 2 \
          "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

case $CHOICE in
  "Full")
    install
    ;;
  "Custom")
    custom
    ;;
  *)
    echo "Exiting..."
    exit 0
    ;;
esac

