#!/bin/bash

# Set up some variables: e.g. efi or bios, what disk to install on, partition to use as /boot etc. 
BOOT_VERSION="bios" # or "efi"
ROOT_PARTITION="sda3"
BOOT_PARTITION="sda1"

read -p "Enter hostname: " HOSTNAME
read -p "Enter root password: " ROOT_PW 
read -p "Enter username: " USER
read -p "Enter user password: " USER_PW

# Check if you have internet connection
ping -c1 -w30 8.8.4.4 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Internet not available, exiting..."
    exit 1
else 
    echo "Internet available"
fi

if [ "x${BOOT_VERSION}" = "xefi" ]; then
    echo "Boot version is efi"
    if [ ! -d /sys/firmware/efi/efivars ]; then 
        echo "Cannot use uefi on this system, exiting..."
        exit 1
    fi
else
    echo "Boot version is bios"
fi

echo "Setting time"

# Set ntp time
timedatectl set-ntp true

echo "Partitioning disk"

# on BIOS, boot partition should be: ext4, having boot flag (a in fdisk), be mounted at /mnt/boot, grub-install should be run at /dev/sda, not on sda1 or similar
# Partition disks
if [ -f /root/partition_disk.sh ]; then
    /root/partition_disk.sh # How to make less hardcoded? As of now, sda1 is boot partition, sda2 is swap, sda3 is root/home partition
else
    echo "partition script not available, exiting..."
    exit 1
fi

echo "Partition type is: $(parted /dev/sda print | grep Partition | cut -d' ' -f3)"

sleep 3

echo "Making filesystems"

# make filesystems, but not on boot/efi
mkfs.ext4 /dev/${ROOT_PARTITION} # sda3 will be our root

echo "Make swap"

# Enable swap
mkswap /dev/sda2 
swapon /dev/sda2

# Check swap status
echo "Swap status: $(swapon -show)"

sleep 3

echo "Adding swap to fstab"

# Add swap row to fstab:
echo "UUID=$(lsblk -no UUID /dev/sda2) none swap defaults 0 0" > /etc/fstab

echo "Making filesystem for boot partition"

if [ "x${BOOT_VERSION}" = "xbios" ]; then
    mkfs.ext4 /dev/${BOOT_PARTITION}
    mkdir -p /mnt/boot
    mount /dev/${BOOT_PARTITION} /mnt/boot
else
    # For efi, make FAT32 filesystem on the partition and mount it
    mkfs.fat -F32 /${BOOT_PARTITION}
    if [ ! -d /boot/efi ]; then 
        echo "No efi directory under /boot, exiting..."
        exit 1
    fi
    mount /dev/${BOOT_PARTITION} /boot/efi
fi

echo "Mounting root partition"

# Mount the root partition
mount /dev/${ROOT_PARTITION} /mnt

lsblk

sleep 3

echo "Running pacstrap"

# Now, for the actual installation
pacstrap /mnt base base-devel linux linux-firmware vim

sleep 3

echo "Generating fstab"

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab

echo "Changing root"

sleep 5

if [ "x${BOOT_VERSION}" = "xbios" ]; then
    arch-chroot /mnt /bin/bash << EOF
        echo "Installing networkmanager"
        pacman --noconfirm -S networkmanager
        systemctl enable NetworkManager
        echo "Installing Grub"
        pacman --noconfirm -S grub
        grub-install --target=i386-pc /dev/sda
        echo "Running grub-mkconfig"
        grub-mkconfig -o /boot/grub/grub.cfg
        §echo "root:${ROOT_PW}" | chpasswd
        echo ${HOSTNAME} > /etc/hostname
        sed -i 's/^#\(sv_SE\|en_US.*$\)/\1/' /etc/locale.gen
        echo "Generating locale"
        locale-gen
        echo "LANG=en_US.UTF-8" > /etc/locale.conf
        echo "Setting timezone"
        if [ -f /usr/share/zoneinfo/Europe/Stockholm ]; then
            ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime 
        else
            echo "Timezone not available, exiting..."
            exit 1
        fi
        echo "Syncing hardware clock to system clock"
        hwclock --systohc
        echo "Setting input language"
        echo "KEYMAP=sv-latin1" > /etc/vconsole.conf
        echo "Adding user..."
   	    sleep 3
   	    useradd -g wheel ${USER}
   	    echo "${USER}:${USER_PW}" | chpasswd
   	    mkdir -p /home/${USER}/Documents
   	    mkdir -p /home/${USER}/Development
   	    mkdir -p /home/${USER}/Pictures
   	    mkdir -p /home/${USER}/Videos
   	    echo "Editing sudoers file..."
   	    sleep 3
   	    echo "%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot" | EDITOR='tee -a' visudo
   	    echo "%wheel ALL=(ALL) ALL" | EDITOR='tee -a' visudo
   	    echo "Generating mirrorlist..."
   	    sleep 5
   	    curl https://www.archlinux.org/mirrorlist/all/ | sed s/^#//g > /etc/pacman.d/mirrorlist
   	    pacman --noconfirm -Syu
   	    echo "Installing graphical interface..."
   	    sleep 3
   	    pacman --noconfirm -S xorg-server xorg-xinit
   
   	    pacman --noconfirm -S i3-gaps git zsh rxvt-unicode urxvt-perls rofi light pulsemixer playerctl imagemagick awk util-linux feh zathura xorg-xrandr cmake gucharmap xorg-xprop redshift libreoffice-fresh libreoffice-fresh-sv stow cscope xorg-xfd xcb-util-xrm chromium firefox file which flashplugin groff ntfs-3g unzip gtk-engine-murrine gtk-engines i3lock wget powerline
   	    pacman --noconfirm -S xorg-xlsfonts noto-fonts bdf-unifont ttf-hack ttf-liberation powerline-fonts awesome-terminal-fonts
   	    pacman -S virtualbox-guest-utils
   
   
   	    pacman --noconfirm -S xf86-video-vmware
   	    systemctl enable vboxservice.service
   	    echo "Changing shell..."
   	    sleep 3
   	    chsh -s /bin/zsh
   	    chsh -s /bin/zsh ${USER}
   	    echo "Finalizing graphical interface setup..."
   	    sleep 2
   	    echo "exec i3" > /home/${USER}/.xinitrc
   	    echo "startx" > /home/${USER}/.zprofile
        echo "Preparing to install aur packages..."
        sleep 3
        mkdir -p /home/${USER}/Development/aur
        cd /home/${USER}/Development/aur
        git clone https://aur.archlinux.org/i3lock-fancy-git.git
        git clone https://aur.archlinux.org/compton-tryone-git.git
        git clone https://aur.archlinux.org/polybar.git
        git clone https://aur.archlinux.org/nerd-fonts-complete.git
        git clone https://aur.archlinux.org/siji-git.git
        echo "Installing dependencies for aur packages..."
        sleep 2
        pacman -S --asdeps --noconfirm libgl libdbus libxcomposite libxdamage pcre libconfig libxinerama hicolor-icon-theme asciidoc dbus wmctrl fontconfig xorg-font-utils cairo xcb-util-image xcb-util-wm xcb-util-cursor python-sphinx xorg-xset libmpdclient
        echo "Install loop..."
        echo "Install loop..."
        echo "Install loop..."
        echo "Install loop..."
        echo "Install loop..."
        echo "Install loop..."
        sleep 6
        for PACK in */; do chown -R nobody "${PACK}"; cd ${PACK}; sudo -u nobody makepkg; PACK_NAME=$(find * -name "*nerd-fonts-complete*.tar.xz"); if [ "x${PACK_NAME}" != "x" ]; then pacman -U --noconfirm "${PACK_NAME}"; else pacman -U --noconfirm *.tar.xz; fi; cd ..; done
        cd ..
        echo "Installing vimix gtk theme..."
        sleep 2
        git clone https://github.com/vinceliuice/vimix-gtk-themes.git
        cd vimix-gtk-themes
        install.sh
        cd /home/${USER}/
        echo "Installing Vundle..."
        sleep 2
        git clone https://github.com/VundleVim/Vundle.vim.git /home/${USER}/.vim/bundle/Vundle.vim
        echo "Installing oh-my-zsh..."
        sleep 2
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

        echo "...and some plugins..."
        sleep 2
        git clone https://github.com/zsh-users/zsh-autosuggestions /home/${USER}/.oh-my-zsh/custom/plugins/zsh-autosuggestions
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /home/${USER}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
   	    echo "Setting ownership of /home/${USER} directory..."
   	    sleep 2
   	    chown -R ${USER} /home/${USER}
   	    sleep 5
EOF
else 
    arch-chroot /mnt /bin/bash << EOF
        echo "Installing networkmanager"
        pacman --nocomfirm -S networkmanager
        systemctl enable NetworkManager
        echo "Installing Grub"
        pacman --nocomfirm -S grub
        pacman --nocomfirm -S efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
        echo "Running grub-mkconfig"
        grub-mkconfig -o /boot/grub/grub.cfg
	echo "root:${ROOT_PW}" | chpasswd
        echo ${HOSTNAME} > /etc/hostname
        sed -i 's/^#\(sv_SE\|en_US.*$\)/\1/' /etc/locale.gen
        echo "Generating locale"
        locale-gen
        echo "LANG=en_US.UTF-8" > /etc/locale.conf
        echo "Setting timezone"
        if [ -f /usr/share/zoneinfo/Europe/Stockholm ]; then
            ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime 
        else
            echo "Timezone not available, exiting..."
            exit 1
        fi
        echo "Syncing hardware clock to system clock"
        hwclock --systohc
        echo "Setting input language"
        echo "KEYMAP=sv-latin1" > /etc/vconsole.conf
	sleep 5
EOF
fi

sleep 3

# Unmount 
#umount -R /mnt

echo "Installation complete, please reboot the system to finish setup"







    

## Install networkmanager
#pacman --nocomfirm -S networkmanager 
#
## Enable it
#systemctl enable NetworkManager
#
#echo "Installing Grub"
#
## Install GRUB
#pacman --nocomfirm -S grub
#
#echo "Running grub-install"
#
#if [ "x${BOOT_VERSION}" = "xbios" ]; then
#    grub-install --target=i386-pc /dev/sda
#else
#    pacman --nocomfirm -S efibootmgr
#    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
#fi
#
#echo "Running grub-mkconfig"
#
## Make grub config 
#grub-mkconfig -o /boot/grub/grub.cfg
#
## Set password for root
#passwd
#
## Get hostname
#read -p "Enter hostname: " HOSTNAME
#
#echo ${HOSTNAME} > /etc/hostname
#
## Uncomment languages in locale.gen:
#sed -i 's/^#\(sv_SE\|en_US.*$\)/\1/' /etc/locale.gen
#
#echo "Generating locale"
#
## Then generate locale
#locale-gen
#
## Set system language
#echo "LANG=en_US.UTF-8" > /etc/locale.conf
#
#echo "Setting timezone"
#
## Set timezone:
#if [ -f /usr/share/zoneinfo/Europe/Stockholm ]; then
#    ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime 
#else
#    echo "Timezone not available, exiting..."
#    exit 1
#fi
#
#echo "Syncing hardware clock to system clock"
#
## Sync hardware clock to system clock
#hwclock --systohc
#
#echo "Setting input language"
#
## Set system input language (NOT SWERTY, NOT YET ANYWAYS)
#echo "KEYMAP=sv-latin1" > /etc/vconsole.conf
#
## Exit root
#exit
#
## Unmount 
#umount -R /mnt
#
## Reboot
#echo "Installation complete, will now reboot the system..."
#sleep 3
#reboot

# Check if you need efi
#
# For boot partition, +200M
# For swap partition, 150% of your ram size, e.g. +12G
# For root/home partition, the rest. If splitting it in two parts, maybe have root as AT LEAST 25G, the rest as home
# Make ext4 filesystem on the /boot partition
# Mount the /root partition on /mnt
# Make folders for mounting the other partitions, so for boot, mkdir /mnt/boot
# Mount it, mount /dev/sda1 /mnt/boot
# after installing grub, do grub-install --target=i386-pc /dev/sda
# Then just grub-mkconfig -i /boot/grub/grub.cfg
#
#
# sed s/^#\(sv_SE\)/\1/ file 
# sed s/^#sv_SE/sv_SE/  file
