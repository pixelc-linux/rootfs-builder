#!/bin/bash
DISTRO_NAME="Ubuntu"

echo -e "[0m[1;31m                          ./+o+-      [0m"
echo -e "[0m[1;37m                  yyyyy- [0m[1;31m-yyyyyy+     [0m"
echo -e "[0m[1;37m               [0m[1;37m://+//////[0m[1;31m-yyyyyyo     [0m"
echo -e "[0m[1;33m           .++ [0m[1;37m.:/++++++/-[0m[1;31m.+sss/\`     [0m"
echo -e "[0m[1;33m         .:++o:  [0m[1;37m/++++++++/:--:/-     [0m"
echo -e "[0m[1;33m        o:+o+:++.[0m[1;37m\`..\`\`\`.-/oo+++++/    [0m"
echo -e "[0m[1;33m       .:+o:+o/.[0m[1;37m          \`+sssoo+/   [0m"
echo -e "[0m[1;37m  .++/+:[0m[1;33m+oo+o:\`[0m[1;37m             /sssooo.  [0m"
echo -e "[0m[1;37m /+++//+:[0m[1;33m\`oo+o[0m[1;37m               /::--:.  [0m"
echo -e "[0m[1;37m \+/+o+++[0m[1;33m\`o++o[0m[1;31m               ++////.  [0m"
echo -e "[0m[1;37m  .++.o+[0m[1;33m++oo+:\`[0m[1;31m             /dddhhh.  [0m"
echo -e "[0m[1;33m       .+.o+oo:.[0m[1;31m          \`oddhhhh+   [0m"
echo -e "[0m[1;33m        \+.++o+o\`[0m[1;31m\`-\`\`\`\`.:ohdhhhhh+    [0m"
echo -e "[0m[1;33m         \`:o+++ [0m[1;31m\`ohhhhhhhhyo++os:     [0m"
echo -e "[0m[1;33m           .o:[0m[1;31m\`.syhhhhhhh/[0m[1;33m.oo++o\`     [0m"
echo -e "[0m[1;31m               /osyyyyyyo[0m[1;33m++ooo+++/    [0m"
echo -e "[0m[1;31m                   \`\`\`\`\` [0m[1;33m+oo+++o\:    [0m"
echo -e "[0m[1;33m                          \`oo++.      [0m"

if [ -z ${RFS_WIFI_SSID+x} ]; then
  echo "WIFI SSID not set! Using 'Pixel C'";
  WIFI_SSID="Pixel C"
fi

if [ -z ${RFS_WIFI_PASSWORD+x} ]; then
  echo "WIFI Password not set! Using 'connectme!'";
  WIFI_PASSWORD="connectme!"
fi

function e_status(){
  echo -e '\e[1;33m'${1}'\e[0;37m'
}

function run_in_qemu(){
  PROOT_NO_SECCOMP=1 proot -0 -r $SYSROOT -q qemu-$ARCH-static -b /etc/resolv.conf -b /etc/mtab -b /proc -b /sys $*
}

ROOTFS_URL='http://cdimage.ubuntu.com/ubuntu-base/daily/current/cosmic-base-arm64.tar.gz'

if [ -f /tmp/rootfs_builder_$DISTRO.tar.gz ]; then
  e_status "$DISTRO_NAME tarball is already available in /tmp/, we're going to use this file."
else
  e_status "Downloading..."
  wget -O /tmp/rootfs_builder_$DISTRO.tar.gz -q $ROOTFS_URL
fi

e_status "Downloading Firmware Files"
wget $(curl https://api.github.com/repos/pixelc-linux/firmware-releases/releases/latest | jq -r '.assets[] | select(.name == "firmware_all.tar.gz") | .browser_download_url') -O /tmp/firmware_all.tar.gz

e_status "Extracting RootFS..."
tar -xf /tmp/rootfs_builder_$DISTRO.tar.gz -C $SYSROOT

e_status "Extracting Firmware Files..."
tar -xf /tmp/firmware_all.tar.gz -C $SYSROOT

e_status "QEMU-chrooting"

#packages="lightdm 
#lightdm-gtk-greeter 
#xf86-video-fbdev 
#binutils 
#make 
#noto-fonts 
#sudo 
#git 
#gcc 
#xorg-xinit 
#xorg-server 
#onboard 
#bluez 
#bluez-tools 
#bluez-utils
#openbox 
#sudo 
#kitty
#netctl
#wpa_supplicant
#dhcpcd
#dialog 
#networkmanager"

packages="bash
bluez
sudo
binutils
ubuntu-minimal
network-manager
lxdm
openbox
onboard
openssh-server
xorg
"

e_status "Installing packages..."

OLDPATH=$PATH
#export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin:/usr/bin

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

#cp $SYSROOT/usr/share/zoneinfo/Europe/Zurich $SYSROOT/etc/localtime
echo "Europe/Zurich" > $SYSROOT/etc/timezone

cp /etc/resolv.conf $SYSROOT/etc/resolv.conf

run_in_qemu uname -a
run_in_qemu apt-get update
run_in_qemu apt-get upgrade

run_in_qemu apt-get install -y $packages

e_status "Setting hostname..."
echo "pixel-c" > $SYSROOT/etc/hostname

run_in_qemu systemctl enable NetworkManager
run_in_qemu systemctl enable lxdm
run_in_qemu systemctl enable bluetooth
run_in_qemu systemctl enable dhcpcd
run_in_qemu systemctl enable sshd


e_status "Adding Keyboard to LightDM"
sed -i 's/#keyboard=/keyboard=onboard/' $SYSROOT/etc/lightdm/lightdm-gtk-greeter.conf

e_status "Adding Wi-Fi connection"
mkdir -p $SYSROOT/etc/NetworkManager/system-connection/
cat > $SYSROOT/etc/NetworkManager/system-connection/wifi-conn-1 <<EOF
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

if [ -z "$KBD_BT_ADDR" ]; then
  e_status "Configuring BT Keyboard"
  
  cat > $SYSROOT/etc/btkbd.conf <<EOF
BTKBDMAC = '$KBD_BT_ADDR'
EOF

e_status "=> Adding BT Keyboard service"

cat > $SYSROOT/etc/systemd/system/btkbd.service <<EOF
[Unit]
Description=systemd Unit to automatically start a Bluetooth keyboard
Documentation=https://wiki.archlinux.org/index.php/Bluetooth_Keyboard
ConditionPathExists=/etc/btkbd.conf
ConditionPathExists=/usr/bin/bluetoothctl

[Service]
Type=oneshot
EnvironmentFile=/etc/btkbd.conf
ExecStart=/usr/bin/bluetoothctl connect \$\{BTKBDMAC\}

[Install]
WantedBy=bluetooth.target
EOF
  run_in_qemu systemctl enable btkbd
fi

if [[ -z $KB_LAYOUT ]] || [[ -z $KB_MAP ]]; then
  KB_LAYOUT="ch"
  KB_MAP="de"
fi

cat > $SYSROOT/etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$KB_LAYOUT"
        Option "XkbModel" "$KB_MAP"
EndSection
EOF

# FSTAB, assume that the rootfs is in /system
cat > $SYSROOT/etc/fstab << EOF
/dev/mmcblk0p4    /               ext4            rw,relatime,data=ordered        0 1
EOF

e_status "Set up LXDM autologin"
sed -E 's/# autologin=.*/autologin=pixelc/g' -i $SYSROOT/etc/lxdm/lxdm.conf

e_status "Add users"
run_in_qemu useradd -m pixelc

e_status "Set passwords"
# Hash for "root"
root_ph='$6$WTgiFCC4$RZ8IN2IkFcLe1tkZAxUdbdS0awm3nUrmyluLAeUhBYf76NIeoBuqinnBIIdxnSB1.PHzDVjVZ1qi8PaHsD/lt1'
# Hash for "pixelc"
pixelc_ph='$6$4MU8USEH$.7mTml0Rq3FkMqmYKw44UQf9lkLp3UCGsY0MYDHK9xIyup6Dc4g/MOtPMDIGxjypH367cPRHPsoxaDdf3yJ9s.'

sed -i -E "s#root:[^:]+:#root:$root_ph:#g" $SYSROOT/etc/shadow
sed -i -E "s#pixelc:[^:]+:#pixelc:$pixelc_ph:#g" $SYSROOT/etc/shadow

e_status "Adding BCM4354.hcd"
wget -O $SYSROOT/lib/firmware/brcm/BCM4354.hcd 'https://github.com/denysvitali/linux-smaug/blob/v4.17-rc3/firmware/bcm4354.hcd?raw=true'

e_status "Removing /var/cache/ content"
rm -rf $SYSROOT/var/cache
mkdir -p $SYSROOT/var/cache

e_status "RootFS generation done."

unset RFS_WIFI_SSID
unset RFS_WIFI_PASSWORD
