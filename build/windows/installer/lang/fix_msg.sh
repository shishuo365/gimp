# Manually patches .isl to mimic AppVerName
# https://groups.google.com/g/innosetup/c/w0sebw5YAeg

langsArray_local=($(ls *.isl*))

if [ "$1" != '-Clean' ]; then
  for langfile in "${langsArray_local[@]}"; do
    #echo "(INFO): patching $langfile"
    cp $langfile $langfile.bak
    before=$(cat $langfile | grep -a 'SetupWindowTitle')
    after=$(cat $langfile | grep -a 'SetupWindowTitle' | sed 's|%1|%1 AppVer|')
    sed -i "s|$before|$after|" $langfile
    before=$(cat $langfile | grep -a 'UninstallAppFullTitle')
    after=$(cat $langfile | grep -a 'UninstallAppFullTitle' | sed 's|%1|%1 AppVer|')
    sed -i "s|$before|$after|" $langfile
  done

else
  rm $langfile
  mv $langfile.bak $langfile
fi