#!/bin/bash

set -e

# $MSYSTEM_CARCH, $MSYSTEM_PREFIX and $MINGW_PACKAGE_PREFIX are defined by MSYS2.
# https://github.com/msys2/MSYS2-packages/blob/master/filesystem/msystem
if [ "$MSYSTEM_CARCH" = "aarch64" ]; then
  export ARTIFACTS_SUFFIX="-a64"
elif [ "$MSYSTEM_CARCH" = "x86_64" ]; then
  export ARTIFACTS_SUFFIX="-x64"
else # [ "$MSYSTEM_CARCH" = "i686" ];
  export ARTIFACTS_SUFFIX="-x86"
fi

if [ -z "$GITLAB_CI" ]; then
  # Make the script work locally
  if [ "$0" != "build/windows/gitlab-ci/2_build-gimp-msys2.sh" ]; then
    echo "To run this script locally, please do it from to the gimp git folder"
    exit 1
  fi
  git submodule update --init --force
  pacman --noconfirm -Suy
  WORK_DIR=$(echo $(dirname $PWD)'/')
  export MESON_OPTIONS="-Drelocatable-bundle=no"
fi


# Install the required (pre-built) packages for GIMP
# We take code from deps script to better maintenance
echo $(cat build/windows/gitlab-ci/1_build-deps-msys2.sh |
       sed -n '/# Install the/,/# End of install/p')     | bash


# Build GIMP
export GIMP_PREFIX="`realpath ${WORK_DIR}_install`${ARTIFACTS_SUFFIX}"
export MSYS2_PREFIX="c:/msys64${MSYSTEM_PREFIX}"
## Universal variables from .gitlab-ci.yml
IFS=$'\n' VAR_ARRAY=($(cat .gitlab-ci.yml | sed -n '/export PATH=/,/GI_TYPELIB_PATH}\"/p' | sed 's/    - //'))
IFS=$' \t\n'
for VAR in "${VAR_ARRAY[@]}"; do
  eval "$VAR" || continue
done

if [ ! -f "_build${ARTIFACTS_SUFFIX}/build.ninja" ]; then
  mkdir -p "_build${ARTIFACTS_SUFFIX}" && cd "_build${ARTIFACTS_SUFFIX}"
  # We disable javascript as we are not able for the time being to add a
  # javascript interpreter with GObject Introspection (GJS/spidermonkey
  # and Seed/Webkit are the 2 contenders so far, but they are not
  # available on MSYS2 and we are told it's very hard to build them).
  # TODO: re-enable javascript plug-ins when we can figure this out.
  meson setup .. -Dprefix="${GIMP_PREFIX}"           \
                 -Dgi-docgen=disabled                \
                 -Djavascript=disabled               \
                 -Ddirectx-sdk-dir="${MSYS2_PREFIX}" \
                 -Dwindows-installer=true            \
                 -Dms-store=true                     \
                 -Dbuild-id=org.gimp.GIMP_official $MESON_OPTIONS
else
  cd "_build${ARTIFACTS_SUFFIX}"
fi
ninja
ninja install
ccache --show-stats


# Wrapper just for easier GIMP running
GIMP_APP_VERSION=$(grep GIMP_APP_VERSION config.h | head -1 | sed 's/^.*"\([^"]*\)"$/\1/')
GIMP_API_VERSION=$(grep GIMP_PKGCONFIG_VERSION config.h | head -1 | sed 's/^.*"\([^"]*\)"$/\1/')

make_cmd ()
{
  echo "@echo off
        echo This is a $1 native build of GIMP$3.
        :: Don't run this under PowerShell since it produces UTF-16 files.
        echo .js   (JavaScript) plug-ins ^|^ NOT supported!
        (
        echo lua=$2\bin\luajit.exe
        echo luajit=$2\bin\luajit.exe
        echo /usr/bin/lua=$2\bin\luajit.exe
        echo /usr/bin/luajit=$2\bin\luajit.exe
        echo :Lua:E::lua::luajit:
        ) >%cd%\lib\gimp\GIMP_API_VERSION\interpreters\lua.interp
        echo .lua  (Lua) plug-ins        ^|^ supported.
        (
        echo python=$2\bin\python.exe
        echo python3=$2\bin\python.exe
        echo /usr/bin/python=$2\bin\python.exe
        echo /usr/bin/python3=$2\bin\python.exe
        echo :Python:E::py::python:
        ) >%cd%\lib\gimp\GIMP_API_VERSION\interpreters\pygimp.interp
        echo .py   (Python) plug-ins     ^|^ supported.
        (
        echo gimp-script-fu-interpreter=%cd%\bin\gimp-script-fu-interpreter-GIMP_API_VERSION.exe
        echo gimp-script-fu-interpreter-GIMP_API_VERSION=%cd%\bin\gimp-script-fu-interpreter-GIMP_API_VERSION.exe
        echo /usr/bin/gimp-script-fu-interpreter=%cd%\bin\gimp-script-fu-interpreter-GIMP_API_VERSION.exe
        echo :ScriptFu:E::scm::gimp-script-fu-interpreter-GIMP_API_VERSION.exe:
        ) >%cd%\lib\gimp\GIMP_API_VERSION\interpreters\gimp-script-fu-interpreter.interp
        echo .scm  (ScriptFu) plug-ins   ^|^ supported.
        echo .vala (Vala) plug-ins       ^|^ supported.
        echo.
        @if not exist $MSYS2_PREFIX\lib\girepository-1.0\babl*.typelib (copy lib\girepository-1.0\babl*.typelib $2\lib\girepository-1.0) > nul
        @if not exist $MSYS2_PREFIX\lib\girepository-1.0\gegl*.typelib (copy lib\girepository-1.0\gegl*.typelib $2\lib\girepository-1.0) > nul
        @if not exist $MSYS2_PREFIX\lib\girepository-1.0\gimp*.typelib (copy lib\girepository-1.0\gimp*.typelib $2\lib\girepository-1.0) > nul
        set PATH=%PATH%;$2\bin
        bin\gimp-$GIMP_APP_VERSION.exe
        @if exist $MSYS2_PREFIX\lib\girepository-1.0\babl*.typelib (if exist lib\girepository-1.0\babl*.typelib (del $2\lib\girepository-1.0\babl*.typelib)) > nul
        @if exist $MSYS2_PREFIX\lib\girepository-1.0\gegl*.typelib (if exist lib\girepository-1.0\gegl*.typelib (del $2\lib\girepository-1.0\gegl*.typelib)) > nul
        @if exist $MSYS2_PREFIX\lib\girepository-1.0\gimp*.typelib (if exist lib\girepository-1.0\gimp*.typelib (del $2\lib\girepository-1.0\gimp*.typelib)) > nul" > ${GIMP_PREFIX}/gimp.cmd
  sed -i "s/GIMP_API_VERSION/${GIMP_API_VERSION}/g" ${GIMP_PREFIX}/gimp.cmd
  sed -i 's|c:/|c:\\|g;s|msys64/|msys64\\|g' ${GIMP_PREFIX}/gimp.cmd
}

if [ "$GITLAB_CI" ]; then
  make_cmd CI %cd% ""
else
  make_cmd local $MSYS2_PREFIX " (please run bin/gimp-${GIMP_APP_VERSION}.exe under $MSYSTEM shell)"
fi
