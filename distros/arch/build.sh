#!/bin/bash

DISTRO_NAME="Arch Linux ARM"

echo -e '
           \e[H\e[2J
          \e[0;36m.
         \e[0;36m/ \
        \e[0;36m/   \      \e[1;37m               #     \e[1;36m| *
       \e[0;36m/^.   \     \e[1;37m a##e #%" a#"e 6##%  \e[1;36m| | |-^-. |   | \ /
      \e[0;36m/  .-.  \    \e[1;37m.oOo# #   #    #  #  \e[1;36m| | |   | |   |  X
     \e[0;36m/  (   ) _\   \e[1;37m%OoO# #   %#e" #  #  \e[1;36m| | |   | ^._.| / \ \e[0;37mTM
    \e[1;36m/ _.~   ~._^\
   \e[1;36m/.^         ^.\ \e[0;37mTM"
'

if [ ! -z "$WIFI_SSID" ]; then
  echo "WIFI SSID not set! Using 'Pixel C'";
  WIFI_SSID="Pixel C"
fi

if [ ! -z "$WIFI_PASSWORD" ]; then
  echo "WIFI Password not set! Using 'connectme!'";
  WIFI_PASSWORD="connectme!"
fi

function e_status(){
  echo -e '\e[1;36m'${1}'\e[0;37m'
}

#if [ "$ARCH" -eq "arm64" ]; then
#  QEMU_ARCH="aarch64"
#fi

function run_in_qemu(){
  PROOT_NO_SECCOMP=1 proot -0 -r $SYSROOT -q qemu-$ARCH-static -b /etc/resolv.conf -b /etc/mtab -b /proc -b /sys $*
}

if [ -f /tmp/rootfs_builder_$DISTRO.tar.gz ]; then
  e_status "$DISTRO_NAME tarball is already available in /tmp/, we're going to use this file."
else
  e_status "Downloading..."
  wget -O /tmp/rootfs_builder_$DISTRO.tar.gz -q 'http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz'
fi

#e_status "Extracting..."
#bsdtar -xpf /tmp/rootfs_builder_$DISTRO.tar.gz -C $SYSROOT 1>/dev/null 2>/dev/null

e_status "QEMU-chrooting"

packages="lightdm 
lightdm-gtk-greeter 
xf86-video-fbdev 
binutils 
make 
noto-fonts 
sudo 
git 
gcc 
xorg-xinit 
xorg-server 
onboard 
bluez 
bluez-tools 
openbox 
sudo 
netctl
wpa_supplicant
dhcpcd
dialog 
networkmanager"

echo $packages

e_status "Installing packages..."
run_in_qemu pacman -Syu --needed --noconfirm $packages

e_status "Setting hostname..."
echo "pixel-c" > $SYSROOT/etc/hostname

run_in_qemu systemctl enable NetworkManager
run_in_qemu systemctl enable lightdm
run_in_qemu systemctl enable bluetooth
run_in_qemu systemctl enable dhcpcd

e_status "Adding Keyboard to LightDM"
sed -i 's/#keyboard=/keyboard=onboard/' $SYSROOT/etc/lightdm/lightdm-gtk-greeter.conf

e_status "Adding Wi-Fi connection"
mkdir -p $SYSROOT/etc/NetworkManager/system-connection/
echo > $SYSROOT/etc/NetworkManager/system-connection/wifi-conn-1 <<EOF
[connection]
id=wifi-conn-1
uuid=4f1ca129-1d42-4b8b-903f-591640da4015
type=wifi
permissions=
[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PASSWORD

[ipv4]
dns-search=
method=auto

[ipv6]
addr-gen-mode=stable-privacy
dns-search=
method=auto
EOF

e_status "RootFS generation done."
