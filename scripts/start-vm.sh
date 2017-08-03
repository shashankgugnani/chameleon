#!/bin/bash
## Script to start a VM 
## Be sure to change the parameters in this file before running

vmac=$1
vnic=$2
vf=$3

tunctl -b -t $vnic
ifconfig $vnic up
brctl addif br0 $vnic

qemu-system-x86_64 \
-enable-kvm \
-daemonize \
-boot c \
-cpu host \
-smp 2 \
-m 2048 \
-hda vm1.qcow2 \
-net nic,macaddr=$vmac,model=virtio \
-net tap,ifname=$vnic,script=no \
-device vfio-pci,host=$3,id=hostdev0 \
-vnc none
