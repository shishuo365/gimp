#!/bin/sh

if [ -n "$GIMP_TEMP_UPDATE_RPATH" ]; then
  # Earlier code used to set DYLD_LIBRARY_PATH environment variable instead, but
  # it didn't work on contributor's builds because of System Integrity
  # Protection (SIP), though it did work in the CI.
  install_name_tool -add_rpath @executable_path/../libgimp $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpbase $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpcolor $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpconfig $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpmath $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpmodule $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpthumb $GIMP_SELF_IN_BUILD
  install_name_tool -add_rpath @executable_path/../libgimpwidgets $GIMP_SELF_IN_BUILD
fi

cat /dev/stdin | $GIMP_SELF_IN_BUILD "$@"

if [ -n "$GIMP_TEMP_UPDATE_RPATH" ]; then
  install_name_tool -delete_rpath @executable_path/../libgimp $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpbase $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpcolor $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpconfig $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpmath $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpmodule $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpthumb $GIMP_SELF_IN_BUILD
  install_name_tool -delete_rpath @executable_path/../libgimpwidgets $GIMP_SELF_IN_BUILD
fi
