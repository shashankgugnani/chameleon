#!/bin/bash
# Script to kill all running VMs on Chameleon

ips=$1
pid=$(ps -e | grep qemu | awk '{ print $1 }')
if [ -n "$pid" ]
then
        kill -9 $pid
fi
for i in `cat $ips`
do
        pid=$(ssh $i ps -e | grep qemu | awk '{ print $1 }')
        if [ -n "$pid" ]
        then
                ssh $i kill -9 $pid
        fi
done
echo "Killed all running VMs"
echo "Deleting all network ports"
/root/destroy-ports.sh $2
