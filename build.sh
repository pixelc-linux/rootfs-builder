#!/bin/bash
#set -e
#. ./env.sh

export ARCH=aarch64
export RFS_WIFI_SSID=$WIFI_SSID
export RFS_WIFI_PASSWORD=$WIFI_PASSWORD

if [ -z "$DISTRO" ]; then
  echo "Distro not set";
  exit
fi

if [ -z "$TOP" ]; then
  echo "TOP not set"
  exit
fi

if [ -z "$SYSROOT" ]; then
  echo "SYSROOT not set";
  exit
fi

if [ ! -d "distros/$DISTRO" ]; then
  echo "Distro \"$DISTRO\" not found!";
  distros=$(ls distros)
  echo "Distros available: $distros";
  exit
fi

if [ ! -f "distros/$DISTRO/build.sh" ]; then
  echo "distros/$DISTRO/build.sh not found!"
  exit;
fi

if [ ! -d "$SYSROOT" ]; then
  echo "SYSROOT directory not found!";
  exit
fi

sudo chown -R $UID:$GID $SYSROOT

distros/$DISTRO/build.sh

# Chmod
sudo chown -R 0:0 $SYSROOT/
sudo chown -R 1000:1000 $SYSROOT/home/alarm

sudo chmod +s $SYSROOT/usr/bin/chfn
sudo chmod +s $SYSROOT/usr/bin/newgrp
sudo chmod +s $SYSROOT/usr/bin/passwd
sudo chmod +s $SYSROOT/usr/bin/chsh
sudo chmod +s $SYSROOT/usr/bin/gpasswd
sudo chmod +s $SYSROOT/bin/umount
sudo chmod +s $SYSROOT/bin/mount
sudo chmod +s $SYSROOT/bin/su

cd $SYSROOT
sudo tar -cvpzf $TOP/out/rootfs.tar.gz .
