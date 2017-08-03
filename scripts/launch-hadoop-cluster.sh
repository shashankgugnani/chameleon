#!/bin/bash
## Script to launch virtual Hadoop cluster on Chameleon
## To be run as root from the master node after
## specifying IP addresses of all nodes (excluding master node)
## and downloading openrc file

# VM Configuration parameters
# Limits: 1. vmpnode * nproc <= host nproc
#	  2. mem * vmpnode <= host mem
#	  3. vmpnode <= 15
vmpnode=$1
mem=$2
nproc=$3

ips=$4
openrc=$5
nohosts=$(cat $4 | wc -l)
novms=$(( $nohosts * $vmpnode + 1 ))

# Wait for all nodes to launch
for ip in `cat $ips`
do
	active=$(ssh-keyscan $ip)
	timeout=4
	while [ -z $active ] && [ $timeout -ne 0 ]
	do
	sleep 30
	active=$(ssh-keyscan $ip)
	timeout=$(( $timeout - 1 ))
	done
	if [ $timeout -eq 0 ]
	then
	echo "FATAL: Not able to ssh to node: $ip"
	echo "Request timed out"
	exit 0
	fi
done

echo -n "" > /root/.ssh/known_hosts
for i in `cat $ips`; do ssh-keyscan $i >> /root/.ssh/known_hosts; done

#Setup ssh login file
echo -n "" > login-file
for i in `cat $ips`
do
	echo "1/ $i" >> login-file
done

#Setup VM launch script
cat << EOF > qemu_create_vm.sh
#!/bin/sh

tunctl -b -t tap\$1
ifconfig tap\$1 up
brctl addif br0 tap\$1
vfio-pci-bind 0000:03:0\$3.\$4

qemu-system-x86_64 \
-enable-kvm \
-daemonize \
-boot c \
-cpu host \
-smp \$6 \
-m \$7 \
-hda /root/vm\$2.qcow2 \
-net nic,macaddr=\$5,model=virtio \
-net tap,ifname=tap\$1,script=no  \
-device vfio-pci,host=03:0\$3.\$4,id=hostdev0 \
-vnc none
EOF

chmod u+x qemu_create_vm.sh
cat $ips | parallel scp qemu_create_vm.sh {}:
cat $ips | parallel ssh {} chmod u+x qemu_create_vm.sh

#Create network ports
#echo "Creating network ports"
#/root/create-ports.sh $novms $openrc

#Launch slave nodes
echo "Launching VMs"
cp /root/chameleon-rdma-hadoop-appliance.qcow2 /root/vm1.qcow2
num=1
for (( j=1; j<=$vmpnode; j++ ))	
do
	cat $ips | parallel scp /root/vm1.qcow2 {}:/root/vm"$j".qcow2
	k=$(( $j - 1 ))
	if [ $j -lt 7 ]
	then
		l=0
		m=$(( $j + 1 ))
	else
		l=1
		m=$(( $j - 6 ))
	fi
	echo -n "" > temp
	for i in `cat $ips`
	do 
		macid=$(sed ""$num"q;d" mac-ids.txt)
		echo $macid >> temp
		num=$(( $num + 1 ))
	done
        cat temp | parallel --sshloginfile login-file ./qemu_create_vm.sh $k $j $l $m {} $nproc $mem
done

#Launch master node
macid=$(cat master-mac-id.txt)
./qemu_create_vm.sh 0 1 0 2 $macid 24 98304
rm temp

#Wait for master node to launch
sleep 100
master_ip=$(head -1 ip-host.txt | awk '{ print $1 }')
active=$(ssh-keyscan $master_ip)
timeout=4
while [ -z $active ] && [ $timeout -ne 0 ]
do
	sleep 30
	active=$(ssh-keyscan $master_ip)
	timeout=$(( $timeout - 1 ))
done
if [ $timeout -eq 0 ]
then
	echo "FATAL: Not able to ssh to master node"
	echo "Request timed out"
	exit 0
fi

#Copy necessary files to master node
ssh-keyscan $master_ip >> /root/.ssh/known_hosts
noslaves=$(( $novms -1 ))
echo $noslaves > noslaves
scp noslaves $master_ip:
scp ip-host.txt $master_ip:

#ssh to master node, wait for node setup and reboot
ssh $master_ip ./vm-reboot-chameleon.sh

#Wait for master node to reboot
sleep 100
active=$(ssh-keyscan $master_ip)
timeout=4
while [ -z $active ] && [ $timeout -ne 0 ]
do
        sleep 30
        active=$(ssh-keyscan $master_ip)
        timeout=$(( $timeout - 1 ))
done
if [ $timeout -eq 0 ]
then
        echo "FATAL: Not able to ssh to master node"
        echo "Request timed out"
        exit 0
fi

#ssh to master node and setup hadoop
ssh $master_ip ./vm-setup-chameleon.sh

#Setup complete; notify user
echo "Cluster setup complete"
echo "RDMA-Hadoop has been installed in /root/rdma-hadoop-<VERSION>"
echo "You can ssh to the master node using 'ssh root@$master_ip'"
echo "NOTE: Some of the slaves might still be initializing. You can ssh to the slave nodes from the master node using 'ssh slaven' (Eg: ssh slave1) and check if RDMA-Hadoop is installed in the /root directory. If not, then please wait for a few minutes and check again"
