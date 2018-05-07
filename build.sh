#!/bin/bash
export ARCH=aarch64

if [ -z "$DISTRO" ]; then
  echo "Distro not set";
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

distros/$DISTRO/build.sh
