#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Wrong number of arguments, exiting..."
    exit 1
fi

BLOCK_DEVICE=$1
if [ $(echo "$(lsblk)" | grep -c "${BLOCK_DEVICE}") -eq 0 ]; then
    echo "That block device does not exit, exiting..."
    exit 1
fi

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${BLOCK_DEVICE}
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1, sda1, boot/efi
    # default - start at beginning of disk
  +500M # 500 MB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2, sda2
    # default, start immediately after preceding partition
  +12G # 12G swap partition
  n # new partition
  p # primary partition
  3 # partition number 3, sda3
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

if [ $? -ne 0 ]; then
    echo "Partitining did not succeed, exiting..."
    exit 1
else
    exit 0
fi
