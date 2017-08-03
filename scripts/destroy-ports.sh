#!/bin/bash
# Script to destroy created network ports on Chameleon
# Run after destroying all running VMs

source $1 
neutron port-list > port-list
mac_id=$(cat master-mac-id.txt)
port=$(grep $mac_id port-list | awk '{ print $2 }')
neutron port-delete $port
for mac_id in `cat mac-ids.txt`
do
        port=$(grep $mac_id port-list | awk '{ print $2 }')
        neutron port-delete $port
done
