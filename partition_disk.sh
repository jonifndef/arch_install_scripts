#!/bin/bash

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
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
