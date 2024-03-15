#!/bin/bash

# Install Inno Setup
wget https://jrsoftware.org/download.php/is.exe
./is.exe //SILENT //SUPPRESSMSGBOXES //CURRENTUSER //SP- //LOG="innosetup.log"

# Get Inno install path
ISCCDIR=`grep "Dest filename:.*ISCC.exe" innosetup.log | sed 's/.*Dest filename: *\|ISCC.exe//g'`
ISCCDIR=`cygpath -u "$ISCCDIR"`


# Download official translations (not present in a Inno release yet)
download_lang_official ()
{
  langfile="$1"
  rm -f "$langfile"
  wget "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/$langfile"
  downloaded="$?"
  if [ $downloaded -ne 0 ]; then
    echo "Download of '$langfile' failed."
    exit 1
  fi
}

mkdir -p "${ISCCDIR}/Languages"
cd "${ISCCDIR}/Languages/"
download_lang_official Korean.isl
cd -


# Download unofficial translations (of unknown quality and maintenance).
# Cf. https://jrsoftware.org/files/istrans/
download_lang ()
{
  langfile="$1"
  rm -f "$langfile"
  wget "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/Unofficial/$langfile"
  downloaded="$?"
  if [ $downloaded -ne 0 ]; then
    echo "Download of '$langfile' failed."
    exit 1
  fi
}

add_bom ()
{
  langfile="$1"
  file "$langfile" |grep "with BOM" 2>&1 > /dev/null
  has_bom="$?"
  if [ $has_bom -ne 0 ]; then
    sed -i "1s/^/\xEF\xBB\xBF/" "$langfile"
  fi
}

mkdir -p "${ISCCDIR}/Languages/Unofficial"
cd "${ISCCDIR}/Languages/Unofficial"
download_lang Basque.isl
download_lang Belarusian.isl
download_lang ChineseSimplified.isl
download_lang ChineseTraditional.isl
# Supposed to be UTF-8 yet missing BOM.
add_bom ChineseTraditional.isl
download_lang EnglishBritish.isl
download_lang Esperanto.isl
download_lang Galician.isl
download_lang Georgian.isl
download_lang Greek.isl
download_lang Indonesian.isl
download_lang Latvian.isl
download_lang Lithuanian.isl
download_lang Malaysian.isl
download_lang Marathi.islu
download_lang Romanian.isl
download_lang Swedish.isl
download_lang Vietnamese.isl
cd -

# Copy generated language files into the source directory.
cp _build-x64/build/windows/installer/lang/*isl build/windows/installer/lang


# Copy generated welcome images into the source directory.
cp _build-x64/build/windows/installer/*bmp build/windows/installer/


# Get list of GIMP supported languages
PO_LIST=`ls po/*.po | \
         sed 's%.*/po/\([a-zA-Z_]*\).po%\1%' | sort`
PO_LIST=`echo "$PO_LIST" | tr '\n\r' ' '` && PO_ARRAY=($PO_LIST)

# Create list of language components
for PO in "${PO_ARRAY[@]}"; do
  NL=$'\n'
  CMP_LINE='Name: loc\PO; Description: "DESC"; Types: full custom'
  CMP_LINE=$(sed "s/PO/$PO/g" <<< $CMP_LINE)

  DESC=`grep -rI '^"Language-Team: .* <' po/$PO.po | \
        sed -e 's/.*Language-Team: \(.*\) <.*/\1/' | sort`
  if [[ -z "$DESC" ]]; then
    DESC="$PO"
  fi
  CMP_LINE=$(sed "s/DESC/$DESC/g" <<< $CMP_LINE)

  CMP_LIST+="${CMP_LINE}${NL}"
done
echo "$CMP_LIST" > build/windows/installer/base_po-cmp.list

# Create list of language folders
for PO in "${PO_ARRAY[@]}"; do
  NL=$'\n'
  DIR_LINE='Source: "{#GIMP_DIR32}\share\locale\PO"; DestDir: "{app}\share\locale"; Components: loc\PO; Flags: recursesubdirs restartreplace uninsrestartdelete ignoreversion'
  DIR_LINE=$(sed "s/PO/$PO/g" <<< $DIR_LINE)

  DIR_LIST+="${DIR_LINE}${NL}"
done
echo "$DIR_LIST" > build/windows/installer/base_po-dir.list


# Construct now the installer.
GIMP_VERSION=`grep -rI '\<version *:' meson.build | head -1 | sed "s/^.*version *: *'\([0-9]\+\.[0-9]\+\.[0-9]\+\)' *,.*$/\1/"`
#GIMP_APP_VERSION_MAJOR=`echo $VERSION | sed "s/^\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)$/\1/"`
#GIMP_APP_VERSION_MINOR=`echo $VERSION | sed "s/^\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)$/\2/"`
#GIMP_APP_VERSION_MICRO=`echo $VERSION | sed "s/^\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)$/\3/"`
cd build/windows/installer
./compile.bat ${GIMP_VERSION} ../../.. gimp-x86 gimp-x64 gimp-a64 ../../.. gimp-x86 gimp-x64 gimp-a64

# Test if the installer was created and return success/failure.
if [ -f "_Output/gimp-${GIMP_VERSION}-setup.exe" ]; then
  cd _Output/
  INSTALLER="gimp-${GIMP_VERSION}-setup.exe"
  sha256sum $INSTALLER > ${INSTALLER}.SHA256SUMS
  sha512sum $INSTALLER > ${INSTALLER}.SHA512SUMS
  exit 0
else
  exit 1
fi
