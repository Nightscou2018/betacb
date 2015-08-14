#!/bin/bash

/home/pi/decoding-carelink/insert.sh 2>/dev/null >/dev/null

openaps pumptime

rawTime=$(grep T clock.json.new)
echo $rawTime

pTime=$(echo $rawTime | mawk '{ sub("T"," ") ; print }')
echo $pTime

date --set=$rawTime 


#pumpStatus=$(openaps use pump522 status)
#sleep 1
#echo $pumpStatus > out/ppout.json

#pumpClock=$(openaps use pump522 read_clock)
#sleep 1
#echo $pumpClock

