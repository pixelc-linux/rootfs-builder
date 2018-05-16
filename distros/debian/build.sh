#!/bin/bash
DISTRO_NAME="Debian"

cat distros/$DISTRO/logo

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

#if [ "$ARCH" -eq "arm64" ]; then
#  QEMU_ARCH="aarch64"
#fi

function run_in_qemu(){
  PROOT_NO_SECCOMP=1 proot -0 -r $SYSROOT -q qemu-$ARCH-static -b /etc/resolv.conf -b /etc/mtab -b /proc -b /sys $*
}

e_status "Debootstrapping..."
debootstrap --arch arm64 jessie $SYSROOT

packages="bash
bluez
sudo
binutils
ubuntu-minimal
network-manager
lightdm
lightdm-gtk-greeter
openbox
onboard
"

e_status "Installing packages..."

OLDPATH=$PATH
#export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin:/usr/bin

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

#cp $SYSROOT/usr/share/zoneinfo/Europe/Zurich $SYSROOT/etc/localtime
echo "Europe/Zurich" > $SYSROOT/etc/timezone

run_in_qemu apt-get update
run_in_qemu apt-get upgrade

exit 1

run_in_qemu apt-get install -y $packages

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
BTKBDMAC = ''$KBD_BT_ADDR''
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
ExecStart=/usr/bin/bluetoothctl connect ${BTKBDMAC}

[Install]
WantedBy=bluetooth.target
EOF
  run_in_qemu systemctl enable btkbd
fi

if [ ! -z "$KB_LAYOUT" -o -! -z "$KB_MAP" ]; then
  KB_LAYOUT = "ch"
  KB_MAP = "de"
fi

cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$KB_LAYOUT"
        Option "XkbModel" "$KB_MAP"
EndSection
EOF

mkdir -p $SYSROOT/home/alarm/.config/openbox
cat > $SYSROOT/home/alarm/.config/openbox/autostart <<EOF 
kitty &
onboard &
EOF

e_status "Adding BCM4354.hcd"
wget -O $SYSROOT/lib/firmware/brcm/BCM4354.hcd 'https://github.com/denysvitali/linux-smaug/blob/v4.17-rc3/firmware/bcm4354.hcd?raw=true'

e_status "Removing /var/cache/ content"
rm -rf $SYSROOT/var/cache
mkdir -p $SYSROOT/var/cache

e_status "RootFS generation done."

unset RFS_WIFI_SSID
unset RFS_WIFI_PASSWORD
