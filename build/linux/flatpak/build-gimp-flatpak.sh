#!/bin/sh

# This script is arch-agnostic. The packager can specify it when calling the script
if [ -z "$1" ]; then
  export ARCH=$(uname -m)
else
  export ARCH=$1
fi


# Build GIMP
if [ -z "$GITLAB_CI" ]; then
  export GIMP_PREFIX="`pwd`/_install-${ARCH}"
else
  export GIMP_PREFIX="`pwd`/../_install-${ARCH}"
fi

if [ ! -f "_build-$ARCH/build.ninja" ]; then
  mkdir -p _build-$ARCH && cd _build-$ARCH
  flatpak build "$GIMP_PREFIX" meson setup .. -Dprefix=/app/ -Dlibdir=/app/lib/
else
  cd _build-$ARCH
fi
flatpak build "$GIMP_PREFIX" ninja
flatpak build "$GIMP_PREFIX" ninja install


if [ "$GITLAB_CI" ]; then
  # Generate a Flatpak bundle to be run with GNOME runtime installed
  flatpak build-bundle repo gimp-git.flatpak --runtime-repo=https://nightly.gnome.org/gnome-nightly.flatpakrepo org.gimp.GIMP ${BRANCH}
  tar cf repo.tar repo/
fi
