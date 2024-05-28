#!/bin/bash

set -e

# $MSYSTEM_CARCH and $MINGW_PACKAGE_PREFIX are defined by MSYS2.
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
  if [ "$0" != "build/windows/gitlab-ci/1_build-deps-msys2.sh" ]; then
    echo "To run this script locally, please do it from to the gimp git folder"
    exit 1
  fi
  export GIT_DEPTH=1
  pacman --noconfirm -Suy
  GIMP_DIR=$(echo "${PWD##*/}/")
  cd $(dirname $PWD) && echo "Using parent folder as work dir"
fi


# Install the required (pre-built) packages for babl and GEGL
DEPS_LIST=$(cat ${GIMP_DIR}build/windows/gitlab-ci/all-deps-uni.txt      |
            sed "s/\${MINGW_PACKAGE_PREFIX}-/${MINGW_PACKAGE_PREFIX}-/g" |
            sed 's/\\//g')

if [ "$MSYSTEM_CARCH" = "aarch64" ]; then
  retry=3
  while [ $retry -gt 0 ]; do
    timeout --signal=KILL 3m pacman --noconfirm -S --needed git                                \
                                                            base-devel                         \
                                                            ${MINGW_PACKAGE_PREFIX}-toolchain  \
                                                            $DEPS_LIST && break
    echo "MSYS2 pacman timed out. Trying again."
    taskkill //t //F //IM "pacman.exe"
    rm -f c:/msys64/var/lib/pacman/db.lck
    : $((--retry))
  done

  if [ $retry -eq 0 ]; then
    echo "MSYS2 pacman repeatedly failed. See: https://github.com/msys2/MSYS2-packages/issues/4340"
    exit 1
  fi
else
  pacman --noconfirm -S --needed git                                \
                                 base-devel                         \
                                 ${MINGW_PACKAGE_PREFIX}-toolchain  \
                                 $DEPS_LIST
fi
# End of install


# Clone babl and GEGL (follow master branch)
clone_or_pull ()
{
  repo="https://gitlab.gnome.org/GNOME/${1}.git"

  if [ "$CI_COMMIT_TAG" != "" ]; then
    # For tagged jobs (i.e. release or test jobs for upcoming releases), use the
    # last tag. Otherwise use the default branch's HEAD.
    tag=$(git ls-remote --tags --exit-code --refs "$repo" | grep -oi "$1_[0-9]*_[0-9]*_[0-9]*" | sort --version-sort | tail -1)
    git_options="--branch=$tag"
    echo "Using tagged release of $1: $tag"
  fi

  if [ ! -d "_${1}" ]; then
    git clone $git_options --depth $GIT_DEPTH $repo _${1} || exit 1
  else
    cd _${1} && git pull && cd ..
  fi
}

clone_or_pull babl
clone_or_pull gegl


# Build babl and GEGL
export GIMP_PREFIX="`realpath ./_install`${ARTIFACTS_SUFFIX}"
## Universal variables from .gitlab-ci.yml
IFS=$'\n' VAR_ARRAY=($(cat ${GIMP_DIR}.gitlab-ci.yml | sed -n '/export PATH=/,/GI_TYPELIB_PATH}\"/p' | sed 's/    - //'))
IFS=$' \t\n'
for VAR in "${VAR_ARRAY[@]}"; do
  eval "$VAR" || continue
done

configure_or_build ()
{
  if [ ! -f "_${1}/_build/build.ninja" ]; then
    mkdir -p _${1}/_build${ARTIFACTS_SUFFIX} && cd _${1}/_build${ARTIFACTS_SUFFIX}
    meson setup .. -Dprefix="${GIMP_PREFIX}" $2
  else
    cd _${1}/_build${ARTIFACTS_SUFFIX}
  fi
  ninja
  ninja install
  ccache --show-stats
  cd ../..
}

configure_or_build babl
configure_or_build gegl '-Dworkshop=true'
