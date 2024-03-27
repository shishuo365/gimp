#!/bin/bash

set -e

export ARTIFACTS_SUFFIX="-x64"


# Build GIMP
mkdir -p "$GIMP_PREFIX"
mkdir -p "_build${ARTIFACTS_SUFFIX}" && cd "_build${ARTIFACTS_SUFFIX}"
meson setup .. -Dprefix="${GIMP_PREFIX}"         \
               -Dgi-docgen=disabled              \
               -Drelocatable-bundle=yes          \
               -Dbuild-id=org.gimp.GIMP_official
ninja
ninja install
cd ..


# Prepare AppImage
sed -i -e "s|$GIMP_DISTRIB/${LIB_DIR}/${LIB_SUBDIR}gdk-pixbuf-.*/.*/loaders/||g" $GIMP_DISTRIB/${LIB_DIR}/${LIB_SUBDIR}gdk-pixbuf-*/*/loaders.cache
cp $GIMP_DISTRIB/usr/share/icons/hicolor/256x256/apps/gimp.png $GIMP_DISTRIB


# Generate AppImage (part 1)
goappimage="appimagetool-817-x86_64.AppImage"
wget "https://github.com/probonopd/go-appimage/releases/download/continuous/$goappimage"
chmod +x "$goappimage"

"./$goappimage" -s deploy $GIMP_DISTRIB/usr/share/applications/gimp.desktop


# Generate AppImage (part 2)
appimagekit="appimagetool-x86_64.AppImage"
wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/$appimagekit"
chmod +x "$appimagekit"

ARCH=x86_64 "./$appimagekit" $GIMP_DISTRIB

whereisappimage=$(find ${GIMP_DISTRIB}/lib/ \( -iname '*.appimage' -or -iname '*.AppImage' \))
echo $whereisappimage

#mv GIMP.AppImage "build/linux/appimage/_Output"
