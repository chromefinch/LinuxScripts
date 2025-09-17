#!/usr/bin/env bash

#mythic install
git clone https://github.com/its-a-feature/Mythic --depth 1 --single-branch
cd Mythic
sudo ./install_docker_kali.sh
sudo make
sudo ./mythic-cli start

#C2 Profiles
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/websocket.git
sudo ./mythic-cli c2 start websocket
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/http
sudo ./mythic-cli c2 start http
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/httpx
sudo ./mythic-cli c2 start httpx
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/smb
sudo ./mythic-cli c2 start smb
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/dynamichttp
sudo ./mythic-cli c2 start dynamichttp

#Agents
sudo ./mythic-cli install github https://github.com/MythicAgents/Apollo.git
sudo ./mythic-cli payload start apollo
sudo ./mythic-cli install github https://github.com/MythicAgents/bloodhound.git
sudo ./mythic-cli payload start bloodhound
sudo ./mythic-cli install github https://github.com/MythicAgents/thanatos
sudo ./mythic-cli payload start thanatos
sudo ./mythic-cli install github https://github.com/MythicAgents/Medusa.git
sudo ./mythic-cli payload start medusa
sudo ./mythic-cli restart
grep -i mythic_admin .env
