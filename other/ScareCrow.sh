#!/bin/bash
# Special shout out to Graham Helton where I first discovered this - https://www.grahamhelton.com/blog/scarecrow/
# Video which demonstrates AV Bypass with this tool -- https://youtu.be/HmiAddzFFac 

sudo apt-get install golang

go install github.com/fatih/color@latest
go install github.com/yeka/zip@latest
go install github.com/josephspurrier/goversioninfo@latest
go install github.com/Binject/debug/pe@latest
go install github.com/awgh/rawreader@latest


sudo apt-get install osslsigncode
sudo apt-get install mingw-w64

mkdir ScareCrowBypass
cd ScareCrowBypass
git clone https://github.com/Tylous/ScareCrow
cd ScareCrow
go build ScareCrow.go
./ScareCrow -h