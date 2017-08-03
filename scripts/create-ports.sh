#!/bin/bash
# Script to create network ports to launch VMs on Chameleon

source $2 
echo -n "" > mac-ids.txt
echo -n "" > ip-host.txt

NODES=$1
USABLE_IPS=0

if [ "$USABLE_IPS" -lt "$NODES" ]
then
        while [ "$USABLE_IPS" -lt "$NODES" ]
        do
                neutron port-create sharednet1 > temp
                IP_ADDR=$(cat temp | grep dns_assignment | awk '{ print $7 }' | grep -Eo '".*"' | sed 's/"//g')
                MAC_ID=$(cat temp | grep mac_address | awk '{ print $4 }')
                if [ $USABLE_IPS -eq 0 ]
                then
                        echo "$MAC_ID" > master-mac-id.txt
                        echo "$IP_ADDR     master" >> ip-host.txt
                else
                        echo "$MAC_ID" >> mac-ids.txt
                        echo "$IP_ADDR     slave$USABLE_IPS" >> ip-host.txt
                fi
                USABLE_IPS=$(( $USABLE_IPS + 1 ))
        done
fi
rm temp
