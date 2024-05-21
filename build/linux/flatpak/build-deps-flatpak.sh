#!/bin/sh

# This script is arch-agnostic. The packager can specify it when calling the script
if [ -z "$1" ]; then
  export ARCH=$(uname -m)
else
  export ARCH=$1
fi


# Install part of the deps
flatpak remote-add --if-not-exists --user --from flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.freedesktop.Sdk.Extension.llvm17 -y
if [ -z "$GITLAB_CI" ]; then
  flatpak remote-add --if-not-exists --user --from gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
  flatpak install --user gnome org.gnome.Platform/${ARCH}/master org.gnome.Sdk/${ARCH}/master -y

  flatpak update -y
fi


# GNOME script to customize gimp module in the manifest (not needed)
#rewrite-flatpak-manifest build/linux/flatpak/org.gimp.GIMP-nightly.json.in gimp ${CONFIG_OPTS}


# Clone and build deps not present in GNOME runtime
if [ "$GITLAB_CI" ]; then
  export GIMP_PREFIX="`pwd`/_install-${ARCH}"
  export BUILD_OPTIONS="--user --disable-rofiles-fuse --repo=repo ${BRANCH:+--default-branch=$BRANCH}"
else
  export GIMP_PREFIX="`pwd`/../_install-${ARCH}"
fi

flatpak-builder --arch=$ARCH      \
                --ccache          \
                --keep-build-dirs \
                --stop-at=gimp    \
                $BUILD_OPTIONS    \
                "$GIMP_PREFIX" build/linux/flatpak/org.gimp.GIMP-nightly.json.in &>flatpak-builder.log
