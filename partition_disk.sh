#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Wrong number of arguments, exiting..."
    exit 1
fi

BLOCK_DEVICE=$1
BOOT_VERSION=$2

if [ $(echo "$(lsblk)" | grep -c "${BLOCK_DEVICE}") -eq 0 ]; then
    echo "That block device does not exit, exiting..."
    exit 1
fi

BLOCK_DEVICE="/dev/${BLOCK_DEVICE}"

if [ "x${BOOT_VERSION}" = "xefi" ]; then
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${BLOCK_DEVICE}
      g # clear the in memory partition table, make the new one gpt
      n # new partition
      1 # partition number 1, sda1, boot/efi
        # default - start at beginning of disk
      +500M # 500 MB boot parttion
      t # change type of the first partition
      1 # 1 for efi system
      n # new partition
      2 # partion number 2, sda2
        # default, start immediately after preceding partition
      +12G # 12G swap partition
      n # new partition
      3 # partition number 3, sda3
        # default, start immediately after preceding partition
        # default, extend partition to end of disk
      p # print the in-memory partition table
      w # write the partition table
      q # and we're done
EOF

else
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${BLOCK_DEVICE}
      g # clear the in memory partition table, make the new one gpt
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
fi

if [ $? -ne 0 ]; then
    echo "Partitining did not succeed, exiting..."
    exit 1
else
    exit 0
fi
