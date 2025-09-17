#!/usr/bin/env bash

#mythic install
git clone https://github.com/its-a-feature/Mythic --depth 1 --single-branch
cd Mythic
sudo ./install_docker_kali.sh
sudo make
sudo ./mythic-cli start

#C2 Profiles
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/websocket.git -f
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/http -f
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/httpx -f
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/smb -f
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/dynamichttp -f

#Agents
sudo ./mythic-cli install github https://github.com/MythicAgents/Apollo.git -f
sudo ./mythic-cli install github https://github.com/MythicAgents/bloodhound.git -f
sudo ./mythic-cli install github https://github.com/MythicAgents/thanatos -f
sudo ./mythic-cli install github https://github.com/MythicAgents/Medusa.git -f
sudo ./mythic-cli restart
grep -i mythic_admin .env
