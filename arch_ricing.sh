#!/bin/bash

# Make sure internet is abvailable:
ping -c1 -w30 8.8.4.4 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Internet not available, exiting..."
    exit 1
else
    echo "Internet available"
fi

sleep 3

# Make sure script is being run as root:
if [ "$EUID" -ne 0 ]; then
    echo "Script must be run as root, exiting..."
    exit 1
fi

sleep 3

if [ -d /sys/class/power_supply ]; then
    PLATFORM=LAPTOP
else
    PLATFORM=DESKTOP
fi

read -p "Enter username: " USER
read -p "Enter password for user ${USER}: " USER_PW

# Add user and its password
useradd -g wheel ${USER}
echo "${USER}:${USER_PW}" | chpasswd
#passwd jonas

sleep 3

mkdir /home/${USER}
mkdir /home/${USER}/Documents
mkdir /home/${USER}/Development
mkdir /home/${USER}/Pictures
mkdir /home/${USER}/Videos
mkdir -p /home/${USER}/.vim/swapfiles # to be set in .vimrc

sleep 3

# Is the 'sudo' part unecessary since script is being run as root? Yes

# Allow any user to run shutdown and reboot
echo "%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot" | EDITOR='tee -a' visudo
echo "%wheel ALL=(ALL) ALL" | EDITOR='tee -a' visudo

sleep 3

# Optinally, make it so that you don't have to re-type root password in a terminal window if you've just done it in another one
#echo "Defaults !tty_tickets" | sudo EDITOR='tee -a' visudo

# Generate mirrorlist
curl https://www.archlinux.org/mirrorlist/all/ | sed s/^#//g > /etc/pacman.d/mirrorlist

sleep 3

# Install some graphical interface packets
pacman --noconfirm -S xorg-server xorg-xinit

sleep 3

# Here we could run 'exec xinit', but let's wait a bit

# Find out which video driver you need
lspci -k | grep -EA3 'VGA|3D|Display'

echo "Which gpu driver do you need?"

sleep 5

#maybe something like blabla | grep -c -i "intel" or "amd", "nvidia" etc..?

# Install window manager and utils:
pacman --noconfirm -S git zsh i3-gaps rxvt-unicode urxvt-perls rofi light pulsemixer playerctl imagemagick awk util-linux feh zathura xorg-xrandr cmake gucharmap xorg-xlsfonts xorg-xprop redshift libreoffice-fresh libreoffice-fresh-sv stow cscope xorg-xfd xcb-util-xrm chromium firefox file which flashplugin groff ntfs-3g unzip gtk-engine-murrine gtk-engines i3lock wget powerline powerline-fonts awesome-terminal-fonts

################# NEW GTK THINGYS #####################

sleep 3 

exit 0

# Beware, this seems iffy, try it a lot...
# Install ctags: 
cd /home/${USER}/Development/
wget http://prdownloads.sourceforge.net/ctags/ctags-5.8.tar.gz
tar -xzf ctags-5.8.tar.gz
rm *.tar.gz
cd ctags-5.8
./configure
make
make install

sleep 3

# Install AUR packages
mkdir /home/${USER}/Development/aur/
cd /home/${USER}/Development/aur/

git clone https://aur.archlinux.org/i3lock-fancy-git.git
git clone https://aur.archlinux.org/compton-tryone-git.git
git clone https://aur.archlinux.org/polybar.git
git clone https://aur.archlinux.org/nerd-fonts-complete.git
git clone https://aur.archlinux.org/siji-git.git

# Potential dependencies for these:
pacman -S --noconfirm libgl libdbus libxcomposite libxdamage libxrandr pcre libconfig libxinerama hicolor-icon-theme asciidoc dbus wmctrl fontconfig xorg-font-utils cairo xcb-util-image xcb-util-wm xcb-util-cursor python-sphinx xorg-xset libmpdclient

# Warning, this is extremely hazardous, running a bunch of makepkg:s without inspecting the contents of those scripts...
for PACK in */; do
    chown -R nobody $PACK
    cd $PACK
    # check deps, grep in PKGBUILD for 'depends', 'makedepends', 'optdepends'
    #list=$(grep depends PKGBUILD | while read -r line; do echo $line | awk -F\" '{ $1=""; print $0 }'; done);
    # install these regulary, but with flag --asdeps
    sudo -u nobody makepkg
    # the following will not for nerdfonts, since there are multiple *tar-files
    PACK_NAME=$(find * -name "*nerd-fonts-complete*.tar.xz")
    if [ "x$PACK_NAME" != "x" ]; then 
        pacman -U --confirm $PACK_NAME
    else
        pacman -U --noconfirm *.tar.xz
    fi
    cd ..
done
cd ..

# you are here
# Little bit different, since you can just run ./Install
git clone https://github.com/vinceliuice/vimix-gtk-themes.git
cd vimix-gtk-themes
install.sh
cd ..

# Install vundle
git clone https://github.com/VundleVim/Vundle.vim.git /home/${USER}/.vim/bundle/Vundle.vim

# And oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# With some plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git .oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# To look up: how to install powerline and ctags and cscope

if [ $(grep -c "zsh" /etc/shells) -gt 0 ] && [ -e /bin/zsh ]; then
    chsh -s /bin/zsh
    chsh -s /bin/zsh ${USER}
fi

sleep 3

# Install oh-my-zsh

# Make the x server start i3 when it starts:
#echo "exec i3" >> ~/.xinitrc
echo "exec i3" > /home/${USER}/.xinitrc

sleep 3

echo "startx" > /home/${USER}/.zprofile

sleep 3

# Then before rebooting, make sure to make everything in /home/jonas belong to, that's right, jonas! run this: chown -R jonas (or ${USER}) /home/${USER}

# If [ videodriverneeded = "vmware" ]; then or something...
pacman -S --noconfirm virtualbox-guest-utils xf86-video-vmware # How to choose interactively??

systemctl enable vboxservice.service

# Install siji from AUR
# Install fonts
pacman --noconfirm -S noto-fonts ttf-font-awesome awesome-terminal-fonts bdf-unifont siji ttf-hack ttf-liberation

sleep 3

# make sure to have all the important files in /home/jonas/before reoobt, like .zshrc .xinitrc .zprofile
echo "#" > /home/${USER}/.zshrc

chown -R ${USER} /home/${USER}

# For testing
exit 0

# Make more modular?
pacman --noconfirm -S xf86-video-intel

# Possibly hack the /etc/X11/xorg.conf to get correct video-driver settings

# For laptop:
if [ "x${PLATFORM}" = "xLAPTOP" ]; then
    # evdev input driver:
    pacman --noconfirm -S xf86-input-evdev
fi

# Video driver:
pacman -S mesa

mkdir -p /home/${USER}/.config

# Copy compton config file: 
cp /etc/xdg/compton.example.conf /home/${USER}/.config/compton.conf

# Set the theme by entering /usy/share/gtk-3.0/ and add set theme in settings.ini:
#gtk-icon-theme-name = vimix-dark
#gtk-theme-name = vimix-dark
#gtk-font-name = Cantarell 11

# And for the gtk-2.0-version, copy the ~/.themes/vimix-dark/gtk-2.0/gtkrc to /usr/share/gtk-2.0/gtkrc 

# uncomment the row #Color in /etc/pacman.conf
# Install powerline
# install YouCompleteMe
# Install OhMyZsh
# Install Vundle
# set up cscope command file with vim
# set up gdb init with pretty printer
