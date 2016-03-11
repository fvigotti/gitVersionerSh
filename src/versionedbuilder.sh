#!/usr/bin/env bash
# create versioned archive of distributables


SOURCES_PROJECT_DIR=`pwd`

print_usage(){
  echo "#####################################################"
  echo "usage: $0 [--debug,--help] [-v (live|last|N.N.N)] [--build-cmd 'gradle dist']  "
  echo "     - all args are optionals ( default will be used )"
  echo "     - version can be given without '-v' ie: ( $0 last|live|1.2.3 ) "
  echo "##### potentially dangerous args : ( break conventions ) ##### "
  echo " --compress|--no-compress  > force compression choices [default: 'yes for versioned, no for live' ]"
  echo " --curbuild-dest  > where the build command place the build [default: 'dist/live' ] "
  echo " --versioned-dest  > where to put versioned distributables [default: 'dist_versioned' ] "
  echo "#####################################################"
}

GIT_CMD_PREVIOUS_TAGGED_VERSION="git tag | sort -V | tail -1"


## parsed args and defaults
ARGS_COMPILE_COMMAND='gradle dist'
ARGS_BUILD_DESTINATION='dist/live'
ARGS_VERSIONED_BUILD_DESTINATION='dist_versioned'
ARGS_VERSION_TO_BUILD='live'
ARGS_CREATE_COMPRESSED='default' # default = (true if is building a version , false if creating a live (it should be not necessary) )

while [[ $# > 0 ]]
do
key="$1"
case $key in
    -v|--version)
    ARGS_VERSION_TO_BUILD="$2"
    shift # past argument
    ;;
    --compress)
      ARGS_CREATE_COMPRESSED="yes"
    ;;
    --no-compress)
      ARGS_CREATE_COMPRESSED="no"
    ;;
    --build-cmd)
      ARGS_COMPILE_COMMAND=$2
      shift # past argument
    ;;
    --curbuild-dest)
      ARGS_BUILD_DESTINATION=$2
      shift # past argument
    ;;
    --versioned-dest)
      ARGS_VERSIONED_BUILD_DESTINATION=$2
      shift # past argument
    ;;
    -h|--help)
    print_usage
    exit 0
    ;;
    --debug)
      set -x
    ;;
    *)
      # smart option parser
      [[ "$key" =~ ^(live|last|[0-9\.]+)$ ]] && {
        echo "smart args parsing.. detected version arg: "$key
        ARGS_VERSION_TO_BUILD=$key
      }
    ;;
esac
shift # past argument or value
done



assertEverythingHasBeenCommitted(){
  [[ -z $(git status -s) ]] || {
    echo '[FATAL ERROR] uncommitted changes, please commit before starting..'
    exit 1
  }
}
assertCorrectVersionFormat(){
  version=$1
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo '[FATAL ERROR] failed to check app version format , version = '$version
    exit 1
  }
}

assertValidGitPath(){
  [ -d "${1}/.git" ] || {
    echo '[FATAL ERROR] wrong expected path, this script is supposed to run from a subdirectory of main project ) project main path extracted = '$1
    exit 1
  }
}
assertBuiltDistributablePathExist(){
  [ -d "${BUILT_DISTRIBUTABLE_PATH}" ] || {
    echo '[FATAL ERROR] expected build distributable path not found '${BUILT_DISTRIBUTABLE_PATH}
    exit 1
  }
}
###############  DEFAULT ASSERTIONS

## assert expected dirs exists
BUILT_DISTRIBUTABLE_PATH="${SOURCES_PROJECT_DIR}/${ARGS_BUILD_DESTINATION}"

VERSIONED_DISTRIBUTABLE_PATH="${SOURCES_PROJECT_DIR}/${ARGS_VERSIONED_BUILD_DESTINATION}"
[ -d "${VERSIONED_DISTRIBUTABLE_PATH}" ] || {
  echo '[FATAL ERROR] expected VERSIONED_DISTRIBUTABLE_PATH not found '${VERSIONED_DISTRIBUTABLE_PATH}' it should already exists!, create that dir and try again'
  exit 1
}

assertValidGitPath $SOURCES_PROJECT_DIR

#####################


clearVersionPattern(){
  ## remove the 'v' if exists in version pattern like ->"v.1.2.3"
  echo $1 | sed "s/v//"
}

assertDirSmallerThan1GB(){
  dirToCheck=$1
  MAX_SIZE_BYTES="1000000000" # 1GB
  CHECK=$(du -sb  $dirToCheck | cut -f1 )
  if [ "$CHECK" -gt "$MAX_SIZE_BYTES" ]; then
     echo '[FATAL ERROR] given dir : ['$dirToCheck'] seems to be greater than 1GB , to avoid dangerous deletion this program cannot delete such dirs '
     exit 10
  fi
}

assertDirBiggerThan1Byte(){
  dirToCheck=$1
  MIN_SIZE_BYTES="1" # Byte
  CHECK=$(du -sb  $dirToCheck | cut -f1 )
  if [ "$CHECK" -lt "$MIN_SIZE_BYTES" ]; then
     echo '[FATAL ERROR] given dir : ['$dirToCheck'] size is lower than 1 byte, something is wrong ? please check and try again'
     exit 1
  fi
}

assertGitTagExist(){
  TAG_TO_CHECK=$1

  checkVersion=$(git rev-list  --quiet $TAG_TO_CHECK --)
  retval=$?
  if [ $retval -ne 0 ]; then
    echo '[FATAL ERROR] invalid git tag ['$TAG_TO_CHECK'] , please use a valid one : ie:'
    git tag | sort -V | tail -10
    exit 1;
  fi
}



build_Live(){
  [ "$ARGS_CREATE_COMPRESSED" = "default" ] && ARGS_CREATE_COMPRESSED="no"
  ARCHIVE_DESTINATION_LIVEVERSION="${VERSIONED_DISTRIBUTABLE_PATH}/live/"

  [ -d $ARCHIVE_DESTINATION_LIVEVERSION ] || mkdir $ARCHIVE_DESTINATION_LIVEVERSION
  assertDirSmallerThan1GB $ARCHIVE_DESTINATION_LIVEVERSION

  ## EXECUTE COMPILATION
  $ARGS_COMPILE_COMMAND
  assertBuiltDistributablePathExist

  ## verify compilation results
  assertDirBiggerThan1Byte $BUILT_DISTRIBUTABLE_PATH

  # copy build results to archive destination for live version
  rsync -avc --delete-after "${BUILT_DISTRIBUTABLE_PATH}/" "${ARCHIVE_DESTINATION_LIVEVERSION}/"
}

build_Versioned(){
  [ "$ARGS_CREATE_COMPRESSED" = "default" ] && ARGS_CREATE_COMPRESSED="yes"

  [ "${ARGS_VERSION_TO_BUILD}" = "last" ] && {
    PREVIOUS_TAGGED_VERSION=$(eval $GIT_CMD_PREVIOUS_TAGGED_VERSION)
    echo 'last version will be built! , extracted last version = '$PREVIOUS_TAGGED_VERSION
    ARGS_VERSION_TO_BUILD=$PREVIOUS_TAGGED_VERSION
  }

  # extract version pure numbers (N.N.N)
  ARGS_VERSION_TO_BUILD=$(clearVersionPattern $ARGS_VERSION_TO_BUILD)
  assertCorrectVersionFormat $ARGS_VERSION_TO_BUILD

  # ie : apppath/dist_versioned/v1.2.3/
  ARCHIVE_DESTINATION_VERSIONED="${VERSIONED_DISTRIBUTABLE_PATH}/v${ARGS_VERSION_TO_BUILD}/"
  echo 'build of version '$ARGS_VERSION_TO_BUILD' will be created in :'$ARCHIVE_DESTINATION_VERSIONED

  [ -d "${ARCHIVE_DESTINATION_VERSIONED}" ] && {
    echo "[WARNING EXIT] requested version is already built! -> ${ARCHIVE_DESTINATION_VERSIONED}"
    exit 0 # SUCCESS!
  }

  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  [ "" != "${CURRENT_BRANCH}" ] || {
    echo '[FATAL ERROR] cannot extract current branch name'${CURRENT_BRANCH}
    exit 1
  }

  BUILDS_TEMP_BRANCH='tempbranch_build_v'$ARGS_VERSION_TO_BUILD

  # checkout in version to build
  git checkout -b $BUILDS_TEMP_BRANCH "v${ARGS_VERSION_TO_BUILD}"

  echo "executing the build..."
  $ARGS_COMPILE_COMMAND
  assertBuiltDistributablePathExist
  assertDirBiggerThan1Byte $BUILT_DISTRIBUTABLE_PATH

  rsync -avc --delete-after "${BUILT_DISTRIBUTABLE_PATH}/" "${ARCHIVE_DESTINATION_VERSIONED}/"

  echo "build complete! going back to previous branch..>"$CURRENT_BRANCH
  git checkout $CURRENT_BRANCH
  git branch -d $BUILDS_TEMP_BRANCH
}


################ EXECUTION


assertEverythingHasBeenCommitted


[ "${ARGS_VERSION_TO_BUILD}" = "live" ] && {
  build_Live
} || {
  build_Versioned
}






