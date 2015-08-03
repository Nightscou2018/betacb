#!/bin/bash
#set -x

# check on stick
stickInfo=$(openaps use pump522 scan)
sleep 1
echo $stickInfo > out/stout.json

pumpStatus=$(openaps use pump522 status)
sleep 1
echo $pumpStatus > out/ppout.json

pumpClock=$(openaps use pump522 read_clock)
sleep 1
echo $pumpClock

#set +x
