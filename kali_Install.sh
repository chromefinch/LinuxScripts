#!/usr/bin/env bash

purple='\033[0;35m'
CL='\033[m'
YW='\033[33m'
BL='\033[36m'
RD='\033[01;31m'
GN='\033[1;92m'
BGN='\033[4;92m'
DGN='\033[32m'
TAB="  "
noticeid="${TAB}${TAB}${CL}"
BFR="\r\033[K"
HOLD="-"
BOLD='\033[1m'
CM="${GN}✓${CL}"

function header_info {
    clear
    echo -e "${purple}"
cat <<'EOF'
.............. 
            ..,;:ccc,.
          ......''';lxO.
.....''''..........,:ld;
            .';;;:::;,,.x,
      ..'''.            0Xxoc:,.  ...
  ....                ,ONkc;,;cokOdc',.
 .                    OMo            ':ddo.
                    dMc                :OO;
                    0M.                  .:o.
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
EOF
echo -e "${CL}"
echo "version 2.1"
}

silent() { "$@" >/dev/null 2>&1; }

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_notice() {
  local msg="$1"
  echo -e "${BFR}${noticeid}${RD}${msg}${CL}"
}

print_red (){
  echo -e "\033[0;31m$1\033[0m"
}   

# Fail on error and report it, debug all lines (removed pipefail to prevent grep crashes)
set -eu 

if [[ $EUID -ne 0 ]]; then
    print_red "This script must be run as root (use sudo)"
    exit 1
fi

# Fallback in case the script is run directly as root without sudo
userid=${SUDO_USER:-$USER}
userhome=$(eval echo ~$userid)

if ! hostnamectl | grep -Eq "Operating System: Kali GNU/Linux Rolling"; then
  echo -e "This version of Linux is not supported"
  echo -e "Requires Kali GNU/Linux Rolling "
  echo -e "Exiting..."
  sleep 2
  exit
fi

install() {
    STD="silent"
    header_info
    rebootMenu
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

    mscode
    letsUpdate
    apps
    tmuxStuff
    chromeInstall
    nvidiaInstall
    xrdpInstall
    rando
    allDone
}

rollKeys() {
case $keyq in
    [yY] ) echo "ok, here we go!" ;
            test -d /etc/ssh/old_keys && echo backup folder already exists, deleting... && sudo rm -rf /etc/ssh/old_keys
            sudo mkdir -p /etc/ssh/old_keys
            test -f old_ssh_signatures.txt && echo 'Cleaning up previous runs' && sudo rm -f new_ssh_signatures.txt old_ssh_signatures.txt || echo '...'
            sudo mv -f /etc/ssh/ssh_host* /etc/ssh/old_keys/ 2>/dev/null || true
            sudo dpkg-reconfigure openssh-server
            
            sudo md5sum /etc/ssh/old_keys/ssh_host* | cut -d "/" -f 1 > old_ssh_signatures.txt || true
            sudo md5sum /etc/ssh/ssh_host* | cut -d "/" -f 1 > new_ssh_signatures.txt
            
            if [[ -z $(grep '[^[:space:]]' old_ssh_signatures.txt) ]] ;then
                echo "Error encountered! The old ssh signature file was not successfully generated, exiting..."
                exit 1
            else
                echo "Old ssh signature file successfully generated."
            fi
            
            if diff -q old_ssh_signatures.txt new_ssh_signatures.txt | grep -q 'differ'; then
                echo "SUCCESS! The SSH keys have been changed successfully."
            else
                echo "FAILURE! The SSH keys have NOT been changed - please manually upgrade the SSH keys..."
                read -p "Have you manually changed ssh keys (y/n)?" choice
                case "$choice" in
                    y|Y ) echo "User manually updated SSH keys and confirmed...";;
                    n|N ) echo "WARNING! Hardening script NOT COMPLETE. Please manually update the SSH keys in /etc/ssh/ssh_host* using dpkg-reconfigure openssh-server and re-run this script..."; exit 1;;
                    *) echo "Invalid response";;
                esac
            fi;;
    * ) msg_ok "Skipping Rolling Keys";;
esac
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
    msg_info "apt fix broken"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y 
    msg_ok "apt fix done"
    msg_info "updating searchsploit"
    $STD sudo searchsploit -u
    msg_ok "searchsploit updated"
    msg_info "running update one more again"
    $STD sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    msg_ok "Updates done"
}

apps() {
    while read -r p ; do 
        $STD sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" && msg_ok "$p installed"
    done < <(cat << "EOF"
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
fastfetch
netexec
feroxbuster
gowitness
sysvinit-utils
gnome-shell-extension-manager
gobuster
gospider
hakrawler
lynis
net-tools
mingw-w64
parallel
yersinia
flameshot
drawing
dysk
EOF
)
    msg_info "Installing flathub"
    $STD sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    msg_ok "Flathub installed"
    
    while read -r p ; do 
        $STD sudo flatpak install --or-update flathub "$p" -y --noninteractive && msg_ok "flathub $p installed"
    done < <(cat << "EOF"
md.obsidian.Obsidian
org.onlyoffice.desktopeditors
com.jetbrains.PyCharm-Community
com.github.tchx84.Flatseal
io.missioncenter.MissionCenter
EOF
)
    msg_info "Installing penelope"
    pipx install git+https://github.com/brightio/penelope || true
}

mscode() {
    msg_info "Adding Microsoft Visual Studio Code repo"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor > packages.microsoft.gpg
    $STD sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    $STD sudo rm -f packages.microsoft.gpg
    msg_ok "Visual Studio Code repo added"
}

tmuxStuff() {
  msg_info "tmux fun"
  cd "$userhome"
  test -d nmap-did-what || git clone https://github.com/chromefinch/nmap-did-what.git
  test -d LinuxScripts || git clone https://github.com/chromefinch/LinuxScripts.git
  chmod +x -R ./LinuxScripts/network 2>/dev/null || true
  
  test -d "$userhome/.tmux.bk" && sudo rm -rf "$userhome/.tmux.bk"
  test -d "$userhome/.tmux.conf.local.bk" && sudo rm -rf "$userhome/.tmux.conf.local.bk"
  test -d "$userhome/.tmux" && sudo mv -f "$userhome/.tmux" "$userhome/.tmux.bk"
  test -f "$userhome/.tmux.conf.local" && sudo mv -f "$userhome/.tmux.conf.local" "$userhome/.tmux.conf.local.bk"
  
  git clone -q https://github.com/gpakosz/.tmux.git "$userhome/.tmux" || true
  ln -s -f .tmux/.tmux.conf "$userhome/.tmux.conf"
  cp "$userhome/.tmux/.tmux.conf.local" "$userhome/"
  sudo chown -R $userid:$userid "$userhome/.tmux" "$userhome/.tmux.conf" "$userhome/.tmux.conf.local" 2>/dev/null || true
  msg_ok "tmux fun installed"

  msg_info "adding update alias and terminal candy"
  term=".$(basename "$SHELL")rc"
  [[ ! -f "$userhome/$term" ]] && term=".bashrc" # fallback
  
  sudo sed -z -i 's|HISTSIZE=1000\nHISTFILESIZE=2000\n|HISTSIZE=1000000\nHISTFILESIZE=2000000\nexport HISTFILE=~/.bash_history\n|g' "$userhome/$term" || true
  sudo sed -z -i "s|alias ll='ls -alF'\n|alias ll='ls -alFh'\n|g" "$userhome/$term" || true
  sudo sed -z -i "s|alias ll='ls -l'\n|alias ll='ls -alFh'\n|g" "$userhome/$term" || true
  sudo sed -z -i 's|HISTSIZE=1000\nSAVEHIST=2000\n|HISTSIZE=1000000\nSAVEHIST=2000000\n|g' "$userhome/$term" || true
  
  alreadythere="$(tail -n 1 "$userhome/$term" 2>/dev/null || echo '')"
  testv="#alreadydoneflag"
  if [ "$alreadythere" = "$testv" ]; then
    msg_ok "shell config already updated"
  else
    cat << EOF >> "$userhome/$term"
fastfetch
alias update="sudo apt update && sudo apt upgrade -y && sudo flatpak update && sudo searchsploit -u"
alias netrset="sudo ~/LinuxScripts/network/netrestart.sh"
alias cpu='watch -n 1 "cat /proc/cpuinfo | grep \"cpu MHz\" | awk '\''{printf \"%.2f GHz\\n\", \$NF/1000}'\'' " '
alias newip='sudo ~/LinuxScripts/network/NewIP.sh'
alias moreip='sudo ~/LinuxScripts/network/MoreIPsPlease.sh'
#alreadydoneflag
EOF
    sudo chown $userid:$userid "$userhome/$term"
    msg_ok "added update alias and terminal candy"
  fi
}

nvidiaInstall() {
    msg_info "Assessing Nvidia HW status"
    if ! lspci | grep -iq "nvidia"; then
        msg_ok "No Nvidia card found, skipping"
    else
        msg_info "Installing proper NVIDIA drivers + OpenCL for Hashcat"
        # Kali requires headers for building the proprietary modules, the drivers, and OpenCL runtime
        $STD sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-$(uname -r) nvidia-driver nvidia-cuda-toolkit nvidia-opencl-icd
        msg_ok "Nvidia drivers, OpenCL, and Cuda Toolkit installed"
    fi
}

chromeInstall() {
  msg_info "installing Google Chrome"
  mkdir -p "$userhome/Downloads"
  cd "$userhome/Downloads"
  chromefile='google-chrome-stable_current_amd64.deb'
  
  if command -v google-chrome >/dev/null 2>&1; then
      msg_ok 'Google Chrome already installed'
  else
      test -f "$chromefile" && msg_ok 'Chrome already downloaded' || wget -q "https://dl.google.com/linux/direct/$chromefile"
      # Using 'apt install' instead of 'dpkg -i' handles pulling in missing dependencies automatically
      $STD sudo DEBIAN_FRONTEND=noninteractive apt install -y "./$chromefile"
      msg_ok "Google Chrome installed"
  fi
}

xrdpInstall() {
    msg_info "Updating xrdp confgs to Gnome Desktop & non standard port"
    sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini
    $STD sudo apt install -y kali-desktop-gnome
    echo "gnome-session" >> "$userhome/.xsession"
    msg_ok "xrdp installed on port 3390 (service not enabled yet)"
    
    cat << 'EOF' > /etc/polkit-1/rules.d/02-allow-colord.rules
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
}

rando() {
    msg_info "Randomizing machine name"
    old=$(cat /etc/hostname)
    array=()
    for i in {A..Z} {0..9}; do
        array[$RANDOM]=$i
    done
    stubsthename="A-$(printf %s ${array[@]::12})"
    $STD sudo sed -i "s/\b$old\b/$stubsthename/g" /etc/hosts
    $STD sudo sed -i "s/\b$old\b/$stubsthename/g" /etc/hostname
    $STD sudo hostname "$stubsthename"
    msg_notice " Renamed $old to $stubsthename"
}

lynisrun() {
    msg_info "Running lynis. Please wait...forever..."
    sudo lynis audit system > "$userhome/lynis_log.txt"
    sudo netstat -tulpn > "$userhome/open_ports_log.txt"
}

rebootMenu() {
  OPTIONS=( n "No auto reboot" y "Auto reboot at end of script")
  rebootq=$(whiptail --backtitle "Kali Post-Install Script" --title "Reboot Option" --menu "Would you like to reboot at the end of this script?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

verboseMenu() {
  OPTIONS=( n "No" y "Yes! I want all the lines!!!")
  prompt=$(whiptail --backtitle "Kali Post-Install Script" --title "Verbose Option" --menu "Would you like to run in verbose mode?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

nvidiaMenu() {
  OPTIONS=( n "No, skip Nvidia/CUDA" y "Yes, install Nvidia/CUDA for Hashcat")
  nvidiaq=$(whiptail --backtitle "Kali Post-Install Script" --title "Nvidia/CUDA Install" --menu "Do you want to install Nvidia/CUDA for Hashcat?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

lynisMenu() {
  OPTIONS=( n "No, skip Lynis" y "Yes, run Lynis")
  lynisq=$(whiptail --backtitle "Kali Post-Install Script" --title "Lynis Scan" --menu "Do you want to run Lynis?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

chromeMenu() {
  OPTIONS=( n "No, skip Chrome" Y "Yes, install Chrome")
  chromeq=$(whiptail --backtitle "Kali Post-Install Script" --title "Google Chrome Install" --menu "Do you want to install Google Chrome?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

xrdpMenu() {
  OPTIONS=( n "No, skip xrdp" Y "Yes, install and configure xrdp")
  xrdpq=$(whiptail --backtitle "Kali Post-Install Script" --title "xrdp Install" --menu "Will you be using xrdp?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

randomizeMenu() {
  OPTIONS=( n "No, keep current name" Y "Yes, randomize machine name")
  randoq=$(whiptail --backtitle "Kali Post-Install Script" --title "Machine Name Randomization" --menu "Do you want to randomize the machine name?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

keyMenu() {
  OPTIONS=( n "No, skip key rolling" y "Yes, roll keys")
  keyq=$(whiptail --backtitle "Kali Post-Install Script" --title "Key Rolling" --menu "Do you want to roll keys?" 10 58 2 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
}

allDone() {
  msg_ok "Ok, I think we're done!\n"
  case $rebootq in 
    [yY]) echo "install app icons taskbar by visiting the following link: https://extensions.gnome.org/extension/4944/app-icons-taskbar/"
        sleep 3
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
    verboseMenu
    if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
        STD=""
    else
        STD="silent"
    fi
    rebootMenu
    nvidiaMenu
    lynisMenu
    chromeMenu
    xrdpMenu
    randomizeMenu
    keyMenu

    header_info
    rollKeys
    mscode
    letsUpdate
    apps
    case $chromeq in
            [nN]) msg_ok "Skipping Google Chrome install";;
            *) chromeInstall;;
    esac
    case $nvidiaq in
            [yY]) nvidiaInstall;;
            *) msg_ok "Skipping Nvidia install";;
    esac
    case $xrdpq in
            [nN]) msg_ok "Skipping xrdp install";;
            *) xrdpInstall;;
    esac
    tmuxStuff
    case $lynisq in
            [yY]) lynisrun;;
            *) msg_ok "Skipping lynis run";;
    esac
    case $randoq in
            [nN]) msg_ok "Skipping machine rename";;
            *) rando;;
    esac
    allDone
}

OPTIONS=(Full "Install (Apps etc, does not roll keys)" \
         Custom "Install, lotsa options")

CHOICE=$(whiptail --backtitle "Kali Helper Scripts" --title "Install Packages" --menu "Select an option:" 10 58 2 \
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
