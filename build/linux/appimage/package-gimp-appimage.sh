#!/bin/sh

# Based on:
# https://github.com/AppImage/AppImageSpec/blob/master/draft.md
# https://gitlab.com/inkscape/inkscape/-/commit/b280917568051872793a0c7223b8d3f3928b7d26

set -e


#UNIVERSAL VARIABLES (do NOT touch them unless to make even more portable)

## This script is arch-agnostic. The packager can specify it when calling the script.
if [[ -z "$1" ]]; then
  export ARCH=$(uname -m)
else
  export ARCH=$1
fi

## This script is "filesystem-agnostic". The packager can quickly choose either
## putting everything in /usr or in AppDir(root) just specifying the 2nd parameter.
GIMP_DISTRIB="$CI_PROJECT_DIR/build/linux/appimage/AppDir"
GIMP_PREFIX="$GIMP_DISTRIB/usr"
if [[ -z "$2" ]] || [[ "$2" == "usr" ]]; then
  OPT_PREFIX="${GIMP_PREFIX}"
elif [[ "$2" == "AppDir" ]]; then
  OPT_PREFIX="${GIMP_DISTRIB}"
fi

## This script is distro-agnostic too.
LIB_DIR=$(gcc -print-multi-os-directory | sed 's/\.\.\///g')
gcc -print-multiarch | grep . && LIB_SUBDIR=$(echo $(gcc -print-multiarch)'/')
export PKG_CONFIG_PATH="${GIMP_PREFIX}/${LIB_DIR}/${LIB_SUBDIR}pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LD_LIBRARY_PATH="${GIMP_PREFIX}/${LIB_DIR}/${LIB_SUBDIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${GIMP_PREFIX}/share:/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export GI_TYPELIB_PATH="${GIMP_PREFIX}/${LIB_DIR}/${LIB_SUBDIR}girepository-1.0${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"


# PREPARE ENVIRONMENT
export CC=clang
export CXX=clang++
apt-get install -y --no-install-recommends clang wget

go_appimagetool="appimagetool-823-x86_64.AppImage"
wget "https://github.com/probonopd/go-appimage/releases/download/continuous/$go_appimagetool"
chmod +x "$go_appimagetool"

legacy_appimagetool="appimagetool-x86_64.AppImage"
wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/$legacy_appimagetool"
chmod +x "$legacy_appimagetool"


# BUILD BABL, GEGL AND GIMP (TEMP)
# Ideally, we should use the bloated Debian pipeline, but we can't because
# #6798 wasn't fixed, which makes appstreamcli check confused and fail

# Build babl
mkdir -p "$GIMP_PREFIX"
git clone --depth=1 https://gitlab.gnome.org/GNOME/babl.git _babl
mkdir _babl/_build-${ARCH} && cd _babl/_build-${ARCH}
meson setup .. -Dprefix="${GIMP_PREFIX}" -Dwith-docs=false
ninja
ninja install

# Build GEGL
cd ../..
git clone --depth=1 https://gitlab.gnome.org/GNOME/gegl.git _gegl
mkdir _gegl/_build-${ARCH} && cd _gegl/_build-${ARCH}
meson setup .. -Dprefix="${GIMP_PREFIX}" -Ddocs=false -Dworkshop=true
ninja
ninja install

# Build GIMP
cd ../..
git submodule update --init
cd gimp-data
git apply -v ../build/linux/appimage/patches/0001-images-logo-Use-reverse-DNS-naming.patch
cd ..
git apply -v build/linux/appimage/patches/0001-desktop-po-Use-reverse-DNS-naming.patch
mkdir -p "_build-${ARCH}" && cd "_build-${ARCH}"
meson setup .. -Dprefix="${GIMP_PREFIX}"         \
               -Dgi-docgen=disabled              \
               -Dbuild-id=org.gimp.GIMP_official
ninja
ninja install


# PACKAGE FILES
cd ..

## Copy coreutils and lldb
find /usr/bin -name mkdir* -execdir cp -r '{}' $OPT_PREFIX/bin \;
find /bin -name mkdir* -execdir cp -r '{}' $OPT_PREFIX/bin \;
find /usr/bin -name lldb* -execdir cp -r '{}' $OPT_PREFIX/bin \;
find /bin -name lldb* -execdir cp -r '{}' $OPT_PREFIX/bin \;

## Copy JavaScript plug-ins support
find /usr/bin -name gjs* -execdir cp -r '{}' $OPT_PREFIX/bin \;
find /bin -name gjs* -execdir cp -r '{}' $OPT_PREFIX/bin \;

## Copy Lua plug-ins support (NOT WORKING)
find /usr/bin -name lua* -execdir cp -r '{}' $OPT_PREFIX/bin \;
find /bin -name lua* -execdir cp -r '{}' $OPT_PREFIX/bin \;
find /usr/${LIB_DIR}/${LIB_SUBDIR} -maxdepth 1 -name liblua* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;
find /usr/${LIB_DIR} -maxdepth 1 -name liblua* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;
find /${LIB_DIR}/${LIB_SUBDIR} -maxdepth 1 -name liblua* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;
find /${LIB_DIR} -maxdepth 1 -name liblua* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;

## Copy Python plug-ins support
find /usr/bin -name python* -exec cp -r '{}' $OPT_PREFIX/bin \;
find /bin -name python* -exec cp -r '{}' $OPT_PREFIX/bin \;
find /usr/${LIB_DIR}/${LIB_SUBDIR} -maxdepth 1 -name python*.* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;
find /usr/${LIB_DIR} -maxdepth 1 -name python*.* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;
find /${LIB_DIR}/${LIB_SUBDIR} -maxdepth 1 -name python*.* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;
find /${LIB_DIR} -maxdepth 1 -name python*.* -execdir cp -r '{}' $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR} \;

## Fix pixbuf (unneeded?)
#sed -i -e "s|$GIMP_PREFIX/${LIB_DIR}/${LIB_SUBDIR}gdk-pixbuf-.*/.*/loaders/||g" $GIMP_PREFIX/${LIB_DIR}/${LIB_SUBDIR}gdk-pixbuf-*/*/loaders.cache

## Copy Glib schemas (unneeded?)
#cp -r /usr/share/glib-* $OPT_PREFIX/share

## Copy iso-codes (NOT WORKING)
mkdir -p $OPT_PREFIX/share/xml/iso-codes
cp -r /usr/share/xml/iso-codes/iso_639.xml $OPT_PREFIX/share/xml/iso-codes

## Copy (most) deps
"./$go_appimagetool" --appimage-extract-and-run -s deploy $GIMP_PREFIX/share/applications/org.gimp.GIMP.desktop

## Rearranje babl, GEGL and GIMP (only the needed files)
### Move files to one place: /usr or AppDir
if [[ -z "$2" ]] || [[ "$2" == "usr" ]]; then
  cp -r $GIMP_DISTRIB/etc $GIMP_PREFIX
  rm -r $GIMP_DISTRIB/etc
  cp -r $GIMP_DISTRIB/lib $GIMP_PREFIX
  rm -r $GIMP_DISTRIB/lib
  cp -r $GIMP_DISTRIB/lib64 $GIMP_PREFIX
  rm -r $GIMP_DISTRIB/lib64
elif [[ "$2" == "AppDir" ]]; then
  cp -r $GIMP_PREFIX/* $GIMP_DISTRIB
  rm -r $GIMP_PREFIX
fi
### Remove unnecessary files
rm -r $OPT_PREFIX/etc/fonts
rm -r $OPT_PREFIX/include
rm -r $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR}gconv
rm -r $OPT_PREFIX/${LIB_DIR}/${LIB_SUBDIR}pkgconfig
rm -r $OPT_PREFIX/share/doc
rm -r $OPT_PREFIX/share/man


# CONFIGURE METADATA
sed -i '/kudo/d' $OPT_PREFIX/share/metainfo/org.gimp.GIMP.appdata.xml
if [[ "$2" == "AppDir" ]]; then
  mkdir -p $GIMP_PREFIX/share
  cp -r $GIMP_DISTRIB/share/metainfo $GIMP_PREFIX/share
  cp -r $GIMP_DISTRIB/share/applications $GIMP_PREFIX/share
fi


# CONFIGURE ICON
cp $OPT_PREFIX/share/icons/hicolor/scalable/apps/org.gimp.GIMP.svg $GIMP_DISTRIB
if [[ "$2" == "AppDir" ]]; then
  cp -r $GIMP_DISTRIB/share/icons/ $GIMP_PREFIX/share
fi


# CONFIGURE APPRUN
cp build/linux/appimage/AppRun $GIMP_DISTRIB

GIMP_APP_VERSION=$(grep GIMP_APP_VERSION _build-${ARCH}/config.h | head -1 | sed 's/^.*"\([^"]*\)"$/\1/')
sed -i "s|GIMP_APP_VERSION|${GIMP_APP_VERSION}|" $GIMP_DISTRIB/AppRun

if [[ -z "$2" ]] || [[ "$2" == "usr" ]]; then
  sed -i "s|OPT_PREFIX_WILD|usr/|g" $GIMP_DISTRIB/AppRun
elif [[ "$2" == "AppDir" ]]; then
  sed -i "s|OPT_PREFIX_WILD||g" $GIMP_DISTRIB/AppRun
fi

configure_apprun ()
{
  export ${1}_RESOLVED=$(realpath --relative-to="${GIMP_DISTRIB}" ${OPT_PREFIX}/$2)
  sed -i "s|${1}_WILD|$(echo "${_##*=}")|" $GIMP_DISTRIB/AppRun
}

configure_apprun GI_TYPELIB_PATH ${LIB_DIR}/${LIB_SUBDIR}girepository-*
configure_apprun BABL_PATH ${LIB_DIR}/${LIB_SUBDIR}babl-*
configure_apprun GEGL_PATH ${LIB_DIR}/${LIB_SUBDIR}gegl-*
configure_apprun GIMP3_SYSCONFDIR etc/gimp/*
configure_apprun GIMP3_PLUGINDIR ${LIB_DIR}/${LIB_SUBDIR}gimp/*
configure_apprun GIMP3_DATADIR share/gimp/*
configure_apprun PYTHONPATH ${LIB_DIR}/${LIB_SUBDIR}python*.*


# MAKE APPIMAGE
"./$legacy_appimagetool" --appimage-extract-and-run $GIMP_DISTRIB -u "zsync|https://download.gimp.org/gimp/v${GIMP_APP_VERSION}/GIMP-latest-${ARCH}.AppImage.zsync"
mkdir build/linux/appimage/_Output
mv GNU*.AppImage build/linux/appimage/_Output
