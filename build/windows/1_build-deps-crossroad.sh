#!/bin/sh

set -e


# SHELL ENV
if [ -z "$CROSSROAD_PLATFORM" ]; then

if [ -z "$GITLAB_CI" ]; then
  # Make the script work locally
   if [ "$0" != 'build/windows/1_build-deps-crossroad.sh' ] && [ ${PWD/*\//} != 'windows' ]; then
    echo -e '\033[31m(ERROR)\033[0m: Script called from wrong dir. Please, read: https://developer.gimp.org/core/setup/build/windows/'
    exit 1
  elif [ ${PWD/*\//} = 'windows' ]; then
    cd ../..
  fi
  export GIT_DEPTH=1
  export GIMP_DIR=$(echo "${PWD##*/}/")
  cd $(dirname $PWD)
fi


## Install crossroad and its deps
if [ "$GITLAB_CI" ]; then
  apt-get install -y --no-install-recommends \
                     wine                    \
                     wine64
fi
git clone --depth $GIT_DEPTH https://gitlab.freedesktop.org/crossroad/crossroad
cd crossroad
git apply ../${GIMP_DIR}build/windows/patches/0001-platforms-Enable-ccache.patch | continue
# Needed because Debian adds by default a local/ folder to the install
# prefix of setup.py. This environment variable overrides this behavior.
export DEB_PYTHON_INSTALL_LAYOUT="deb"
./setup.py install --prefix=`pwd`/../.local
cd ..


# CROSSROAD ENV
export PATH="$PWD/.local/bin:$PATH"
export XDG_DATA_HOME="$PWD/.local/share"
crossroad w64 gimp --run="${GIMP_DIR}build/windows/1_build-deps-crossroad.sh"
else

## Install the required (pre-built) packages for babl, GEGL and GIMP
crossroad source msys2
crossroad install $(cat ${GIMP_DIR}build/windows/all-deps-uni.txt |
                    sed "s/\${MINGW_PACKAGE_PREFIX}-//g" | sed 's/\\//g')
if [ $? -ne 0 ]; then
  echo "Installation of pre-built dependencies failed.";
  exit 1;
fi

## Prepare env (no env var is needed, all are auto set to CROSSROAD_PREFIX)
export ARTIFACTS_SUFFIX="-cross"

## Build babl and GEGL
source "$(cat build/windows/1_build-deps-msys2.sh | sed -n '/self_build ()/,/# End of self_build/p' |
          sed -e 's/meson/crossroad meson/g' -e "s/_build/_build$ARTIFACTS_SUFFIX/g")"

self_build babl '-Denable-gir=false'
self_build gegl '-Dintrospection=false'

## FIXME: Build manually gio 'giomodule.cache' to fix error about
## absent libgiognutls.dll that prevents generating loaders.cache
echo 'libgiognomeproxy.dll: gio-proxy-resolver
libgiognutls.dll: gio-tls-backend
libgiolibproxy.dll: gio-proxy-resolver
libgioopenssl.dll: gio-tls-backend' > $CROSSROAD_PREFIX/lib/gio/modules/giomodule.cache

## FIXME: Build manually pixbuf 'loaders.cache' for GUI image support
echo '"lib\\gdk-pixbuf-2.0\\2.10.0\\loaders\\libpixbufloader-png.dll"
      "png" 5 "gdk-pixbuf" "PNG" "LGPL"
      "image/png" ""
      "png" ""
      "\211PNG\r\n\032\n" "" 100

      "lib\\gdk-pixbuf-2.0\\2.10.0\\loaders\\libpixbufloader-svg.dll"
      "svg" 6 "gdk-pixbuf" "Scalable Vector Graphics" "LGPL"
      "image/svg+xml" "image/svg" "image/svg-xml" "image/vnd.adobe.svg+xml" "text/xml-svg" "image/svg+xml-compressed" ""
      "svg" "svgz" "svg.gz" ""
      " <svg" "*    " 100
      " <!DOCTYPE svg" "*             " 100

      ' > $(echo $CROSSROAD_PREFIX/lib/gdk-pixbuf-*/*/)/loaders.cache

## FIXME: Build manually glib 'gschemas.compiled'
GLIB_PATH=$(echo $CROSSROAD_PREFIX/share/glib-*/schemas/)
wine $CROSSROAD_PREFIX/bin/glib-compile-schemas.exe --targetdir=$GLIB_PATH $GLIB_PATH >/dev/null 2>&1

fi # END OF CROSSROAD ENV
