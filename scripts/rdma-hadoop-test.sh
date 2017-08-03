#!/bin/bash
## Script to test if all bare-metal nodes have been setup correctly

ips=$1

echo -n "" > /root/.ssh/known_hosts
for i in `cat $ips`; do ssh-keyscan $i >> /root/.ssh/known_hosts; done
echo -n "" > /home/cc/.ssh/known_hosts
for i in `cat $ips`; do ssh-keyscan $i >> /home/cc/.ssh/known_hosts; done

echo -n "Checking SR-IOV availability ... "
sriov=$(lspci | grep Mellanox | wc -l)
if [ $sriov -lt 2 ]
then
	echo "FAILED"
	echo "Please contact the Chameleon help-desk about this issue"
	exit 0
fi

for i in `cat $ips`
do
	sriov=$(ssh $i lspci | grep Mellanox | wc -l)
	if [ $sriov -lt 2 ]
	then
        	echo "FAILED"
		echo "Please contact the Chameleon help-desk about this issue"
		exit 0
	fi
done
echo "OK"
echo "Nodes are ready to be used"
