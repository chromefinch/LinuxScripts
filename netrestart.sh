#!/bin/bash
ip -br a
sudo service networking restart
sudo service NetworkManager restart
echo ""
echo now           
echo ""
ip -br a
