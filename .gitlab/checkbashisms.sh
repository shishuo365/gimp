#!/bin/sh

# Only check modified scripts
mr_branch=$(git symbolic-ref --short HEAD)
mr_content=$(git diff master $mr_branch -U0 -- '*.sh' |
             grep '^[+]' | grep -Ev '(--- a/|\+\+\+ b/)')
if [ -z "$mr_content" ]; then
  echo 'No scripts were modified. Check for bashisms skipped.'
  exit 0
fi

# Check for bashisms
echo $mr_content > > mr_diff
.gitlab/checkbashisms.pl -f -x mr_diff > bashisms.log

# Return error value to CI
if [ $? -eq 0 ] || [ $? -eq 4 ]; then
  echo 'No bashisms detected'
  echo ""
  exit 0
else
  echo ""
  exit 1
fi
