#!/bin/bash

set -e

# $MSYSTEM_CARCH and $MSYSTEM_PREFIX are defined by MSYS2.
# https://github.com/msys2/MSYS2-packages/blob/master/filesystem/msystem
if [ "$MSYSTEM_CARCH" = "aarch64" ]; then
  export ARTIFACTS_SUFFIX="-a64"
elif [ "$CI_JOB_NAME" = "gimp-win-x64-cross" ] || [ "$MSYSTEM_CARCH" = "x86_64" ]; then
  export ARTIFACTS_SUFFIX="-x64"
else # [ "$MSYSTEM_CARCH" = "i686" ];
  export ARTIFACTS_SUFFIX="-x86"
fi


if [[ "$CI_JOB_NAME" =~ "cross" ]]; then
  apt-get update
  apt-get install -y --no-install-recommends   \
                     binutils                  \
                     binutils-mingw-w64-x86-64 \
                     file                      \
                     libglib2.0-bin            \
                     python3
fi


# Bundle deps and GIMP files
if [[ "$CI_JOB_NAME" =~ "cross" ]]; then
  export GIMP_PREFIX="`realpath ./_install`${ARTIFACTS_SUFFIX}-cross"
  export MSYS_PREFIX="$GIMP_PREFIX"
else
  export GIMP_PREFIX="`realpath ./_install`${ARTIFACTS_SUFFIX}"
  export MSYS_PREFIX="c:/msys64${MSYSTEM_PREFIX}"
fi
export GIMP_DISTRIB="`realpath ./gimp`${ARTIFACTS_SUFFIX}"


bundle ()
{
  path=$(echo "$1" | cut -d'/' -f3-)
  dir_or_file="${path: -1}"
  if [ "$dir_or_file" = '/' ]; then
    mkdir -p "$GIMP_DISTRIB/$path"
    cp -r "$1" "$GIMP_DISTRIB/$(dirname $GIMP_DISTRIB/$path)"
  else
    path_from_file=${path%/*}
    mkdir -p "$GIMP_DISTRIB/$path_from_file"
    cp -r "$1" "$GIMP_DISTRIB/$(dirname $GIMP_DISTRIB/$path_from_file)"
}

clean ()
{
  find "$1" -iname $2 -execdir rm '{}' \;
}


## Copy a previously built wrapper at tree root, less messy than
## having to look inside bin/, in the middle of all the DLLs.
## This also configure the interpreters for local builds as courtesy.
bundle "$GIMP_PREFIX/*.cmd"


## Settings.
bundle "$GIMP_PREFIX/etc/gimp/"
### Needed for fontconfig work
bundle "$MSYS_PREFIX/etc/fonts/"


## Headers (in evaluation).
#bundle $GIMP_PREFIX/include/babl-*/
#bundle $GIMP_PREFIX/include/gegl-*/
#bundle $GIMP_PREFIX/include/gimp-*/


## Library data.
bundle "$GIMP_PREFIX/lib/babl-*/"
bundle "$MSYS_PREFIX/lib/gdk-pixbuf-*/*/loaders/libpixbufloader-png.dll"
bundle "$MSYS_PREFIX/lib/gdk-pixbuf-*/*/loaders/libpixbufloader-svg.dll"
bundle "$GIMP_PREFIX/lib/gegl-*/"
bundle "$GIMP_PREFIX/lib/gimp/"
bundle "$MSYS_PREFIX/lib/gio/"
clean "$GIMP_DISTRIB/lib" *.a


## Resources.
bundle "$GIMP_PREFIX/share/gimp/"
### Needed for file dialogs
bundle "$MSYS_PREFIX/share/glib-*/schemas/"
### https://gitlab.gnome.org/GNOME/gimp/-/issues/6165
bundle "$MSYS_PREFIX/share/icons/Adwaita/"
### https://gitlab.gnome.org/GNOME/gimp/-/issues/5080
bundle "$GIMP_PREFIX/share/icons/hicolor/"
### Needed for wmf work
bundle "$MSYS_PREFIX/share/libwmf/"
### Only copy from langs supported in GIMP.
bundle "$GIMP_PREFIX/share/locale/"
for dir in ${GIMP_DISTRIB}/share/locale/*/; do
  lang=`basename "$dir"`;
  if [ -d "$MSYS_PREFIX/share/locale/$lang/LC_MESSAGES/" ]; then
    bundle "$MSYS_PREFIX/share/locale/$lang/LC_MESSAGES/"gimp*.mo
    bundle "$MSYS_PREFIX/share/locale/$lang/LC_MESSAGES/"gegl*.mo
    bundle "$MSYS_PREFIX/share/locale/$lang/LC_MESSAGES/"gtk*.mo
    bundle "$MSYS_PREFIX/share/locale/$lang/LC_MESSAGES/"iso_639*.mo
  fi
done
### Needed for welcome page
bundle "$GIMP_PREFIX/share/metainfo/org.gimp*.xml"
### mypaint brushes
bundle "$MSYS_PREFIX/share/mypaint-data/"
### Needed for lang selection in Preferences
bundle "$MSYS_PREFIX/share/xml/iso-codes/iso_639.xml"


## Executables and DLLs.

### We save the list of already copied DLLs to keep a state between 3_bundle-gimp-uni_dep runs.
rm -f done-dll.list

### Minimal (and some additional) executables for the 'bin' folder
bundle "$MSYS_PREFIX/bin/bzip2.exe"
### https://gitlab.gnome.org/GNOME/gimp/-/issues/6045
bundle "$MSYS_PREFIX/bin/dot.exe"
### https://gitlab.gnome.org/GNOME/gimp/-/issues/8877
bundle "$MSYS_PREFIX/bin/gdbus.exe"
# https://gitlab.gnome.org/GNOME/gimp/-/issues/10580
bundle "$GIMP_PREFIX/bin/gegl*.exe"
bundle "$GIMP_PREFIX/bin/gimp*.exe"


### .pdb (CodeView) debug symbols
### crossroad don't have LLVM/Clang backend yet
#if [ "$CI_JOB_NAME" != "gimp-win-x64-cross" ]; then
#  cp -fr ${GIMP_PREFIX}/bin/*.pdb ${GIMP_DISTRIB}/bin/
#fi

## Optional executables, .DLLs and resources for GObject Introspection support
if [[ ! "$CI_JOB_NAME" =~ "cross" ]]; then
  bundle "$MSYS_PREFIX/bin/libgirepository-*.dll"
  bundle "$GIMP_PREFIX/lib/girepository-*/*"

  bundle "$MSYS_PREFIX/bin/luajit.exe"
  bundle "$MSYS_PREFIX/lib/lua/"

  bundle "$MSYS_PREFIX/bin/python*.exe"
  bundle "$MSYS_PREFIX}/lib/python*/"
else
  # Just to ensure there is no introspected files that will output annoying warnings
  # This is needed because meson.build files can have flaws
  clean "$GIMP_DISTRIB" '*.lua'
  clean "$GIMP_DISTRIB" '*.py'
  clean "$GIMP_DISTRIB" '*.scm'
  clean "$GIMP_DISTRIB" '*.vala'
fi

### Needed DLLs for the executables or DLLs in the 'bin'  and lib' sub-folders
libArray=($(find "$GIMP_DISTRIB" \( -iname '*.dll' -or -iname '*.exe' \)))
for lib in "${libArray[@]}"; do
  python3 build/windows/gitlab-ci/3_bundle-gimp-uni_dep.py $lib ${GIMP_PREFIX}/ ${MSYS_PREFIX}/ ${GIMP_DISTRIB} --output-dll-list done-dll.list;
done
