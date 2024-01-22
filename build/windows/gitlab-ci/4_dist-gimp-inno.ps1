#!/usr/bin/env pwsh

param ($GIMP_VER,
       $GIMP_BASE,
       $GIMP32,
       $GIMP64,
       $GIMPA64,
       $DEPS_VER,
       $DEPS_BASE,
       $DEPS32,
       $DEPS64,
       $DEPSA64)


# Install or Update Inno Setup
Invoke-WebRequest -URI "https://jrsoftware.org/download.php/is.exe" -OutFile "is.exe"
.\is.exe /SILENT /SUPPRESSMSGBOXES /CURRENTUSER /SP- /LOG="innosetup.log"
Wait-Process is

# Get Inno install path
$log = Get-Content -Path 'innosetup.log' | Select-String 'ISCC.exe'
$pattern = '(?<=filename: ).+?(?=\\ISCC.exe)'
$INNOPATH = [regex]::Matches($log, $pattern).Value

# Get Inno install path (fallback)
#$INNOPATH = Get-ItemProperty -Path Registry::'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1' |
#Select-Object -ExpandProperty "InstallLocation"
# if ($INNOPATH -eq "")
#   {
#     $INNOPATH = Get-ItemProperty -Path Registry::'HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1' |
#     Select-Object -ExpandProperty "InstallLocation"
#   }


# Download Official translations (not present in a Inno release yet)
function download_lang_official ([string]$langfile)
  {
    $installed = Test-Path -Path "$langfile" -PathType Leaf
    if ($installed -eq "True")
      {
        Remove-Item -Path "$langfile" -Force
      }
    Invoke-WebRequest -URI "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/${langfile}" -OutFile "$INNOPATH/Languages/${langfile}"
  }

New-Item -ItemType Directory -Path "$INNOPATH/Languages/" -Force
download_lang_official Korean.isl

# Download Unofficial translations (of unknown quality and maintenance)
# Cf. https://jrsoftware.org/files/istrans/
function download_lang ([string]$langfile)
  {
    $installed = Test-Path -Path "$langfile" -PathType Leaf
    if ($installed -eq "True")
      {
        Remove-Item -Path "$langfile" -Force
      }
    Invoke-WebRequest -URI "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/Unofficial/${langfile}" -OutFile "$INNOPATH/Languages/Unofficial/${langfile}"
  }

New-Item -ItemType Directory -Path "$INNOPATH/Languages/Unofficial/" -Force
download_lang Basque.isl
download_lang Belarusian.isl
download_lang ChineseSimplified.isl
download_lang ChineseTraditional.isl
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


$debian_generated = Test-Path -Path "_build-x64/build/windows/installer"
  if ($debian_generated -eq "True")
    {
      # Copy generated language files into the source directory
      Copy-Item _build-x64/build/windows/installer/lang/*isl build/windows/installer/lang

      # Copy generated welcome images into the source directory
      Copy-Item _build-x64/build/windows/installer/*bmp build/windows/installer/
    }


# Construct now the installer
Set-Location build/windows/installer
Set-Alias -Name 'iscc' -Value "${INNOPATH}\iscc.exe"

if ($PSBoundParameters.ContainsKey('GIMP_VER'))
  {
    iscc -DGIMP_VERSION="$GIMP_VER" -DGIMP_DIR="$GIMP_BASE" -DDIR32="$GIMP32" -DDIR64="$GIMP64" -DDIRA64="$GIMPA64" -DDEPS_VERSION="$DEPS_VER" -DDEPS_DIR="$DEPS_BASE" -DDDIR32="$DEPS32" -DDDIR64="$DEPS64" -DDDIRA64="$DEPSA64" -DDEBUG_SYMBOLS -DPYTHON -DLUA base_gimp3264.iss
  }
else
  {
    Write-Host "No arguments were passed, auto setting them"
    $GIMP_VERSION = Get-Content -Path '..\..\..\meson.build' | Select-Object -Index 2                         |
                                                               Foreach-Object {$_ -replace "  version: '",""} |
                                                               Foreach-Object {$_ -replace "',",""}
    $DEPS_VERSION = Get-Content -Path '..\..\..\meson.build' | Select-String 'gtk_minver       ='                     |
                                                               Foreach-Object {$_ -replace "gtk_minver       = '",""} |
                                                               Foreach-Object {$_ -replace "'",""}
    iscc -DGIMP_VERSION="$GIMP_VERSION" -DGIMP_DIR="../../.." -DDIR32="gimp-x86" -DDIR64="gimp-x64" -DDIRA64="gimp-a64" -DDEPS_VERSION="$DEPS_VERSION" -DDEPS_DIR="../../.." -DDDIR32="gimp-x86" -DDDIR64="gimp-x64" -DDDIRA64="gimp-a64" -DDEBUG_SYMBOLS -DPYTHON -DLUA base_gimp3264.iss
  }


# Test if the installer was created and return success/failure.
$builded = Test-Path -Path "_Output/gimp-${GIMP_VERSION}-setup.exe" -PathType Leaf
if ($builded -eq "True")
  {
    Set-Location _Output/
    $INSTALLER="gimp-${GIMP_VERSION}-setup.exe"
    Get-FileHash $INSTALLER -Algorithm SHA256 | Out-File -FilePath "${INSTALLER}.SHA256SUMS"
    Get-FileHash $INSTALLER -Algorithm SHA512 | Out-File -FilePath "${INSTALLER}.SHA512SUMS"
    exit 0
  }
else
  {
    exit 1
  }


# Return to git golder
Set-Location ..\..\..\