#!/bin/sh

set -e


# CROSSROAD ENV
export ARTIFACTS_SUFFIX="-x64"

## The required packages for GIMP are taken from the previous job

## Build GIMP
mkdir _build${ARTIFACTS_SUFFIX}-cross && cd _build${ARTIFACTS_SUFFIX}-cross
crossroad meson setup .. -Dgi-docgen=disabled                 \
                         -Djavascript=disabled -Dlua=disabled \
                         -Dpython=disabled -Dvala=disabled
ninja
ninja install
ccache --show-stats
cd ..

## Wrapper just for easier GIMP running (to not look at the huge bin/ folder with many .DLLs)
GIMP_APP_VERSION=$(grep GIMP_APP_VERSION _build${ARTIFACTS_SUFFIX}-cross/config.h | head -1 | sed 's/^.*"\([^"]*\)"$/\1/')
echo "@echo off
      echo This is a CI crossbuild of GIMP.
      :: Don't run this under PowerShell since it produces UTF-16 files.
      echo .js   (JavaScript) plug-ins ^|^ NOT supported!
      echo .lua  (Lua) plug-ins        ^|^ NOT supported!
      echo .py   (Python) plug-ins     ^|^ NOT supported!
      echo .scm  (ScriptFu) plug-ins   ^|^ NOT supported!
      echo .vala (Vala) plug-ins       ^|^ NOT supported!
      echo.
      bin\gimp-$GIMP_APP_VERSION.exe" > ${CROSSROAD_PREFIX}/gimp.cmd

## Copy built GIMP, babl and GEGL and pre-built packages to GIMP_PREFIX
cp -fr $CROSSROAD_PREFIX/ _install${ARTIFACTS_SUFFIX}-cross/
