#!/usr/bin/env bash

set -xe ## debug everything in this script

export GITVERSIONER_DEST_PATH=/usr/bin/gitversioner
export VERSIONEDBUILDER_DEST_PATH=/usr/bin/versionedbuilder
echo "install gitversioner in  ${GITVERSIONER_DEST_PATH} and ${VERSIONEDBUILDER_DEST_PATH} "

CURRENT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TMP_APP_DIR="/tmp/.install-gitversioner"


downloadFromGithub(){
  DESTIONATION_PATH=$1
  GITHUB_SRC_REPO=https://github.com/fvigotti/gitVersionerSh
  echo "downloading from github $GITHUB_SRC_REPO"
  [ -d "${DESTIONATION_PATH}" ] || mkdir ${DESTIONATION_PATH}
  cd "${DESTIONATION_PATH}"
  [ -d "./gitVersionerSh" ] && {
    git pull $GITHUB_SRC_REPO
  } || {
    git clone $GITHUB_SRC_REPO
  }

}

install_from_path(){
  PROGRAM_PATH=$1
  cp "${PROGRAM_PATH}/gitversioner.sh" "${GITVERSIONER_DEST_PATH}"
  chmod 755 "${GITVERSIONER_DEST_PATH}"
  cp "${PROGRAM_PATH}/versionedbuilder.sh" "${VERSIONEDBUILDER_DEST_PATH}"
  chmod 755 "${VERSIONEDBUILDER_DEST_PATH}"
}

echo "check if app has been already downloaded"
[ -f "${CURRENT_DIR}/../gitversioner.sh" ] && {
  echo "script found in current path, installing the version found in :""${CURRENT_DIR}/.."
  install_from_path "${CURRENT_DIR}/.."
} || {
  downloadFromGithub $TMP_APP_DIR
  install_from_path ${TMP_APP_DIR}
}