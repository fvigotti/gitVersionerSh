#!/usr/bin/env bash
GIT_PROJECT_DIR=`pwd`

if [[ $# < 1 ]]; then
  echo "usage: $0 [--debug,--major] start|end|patch "
fi

####### CONSTANTS
GIT_CMD_CURRENT_BRANCH="git rev-parse --abbrev-ref HEAD"
GIT_CMD_PREVIOUS_TAGGED_VERSION="git tag | sort -V | tail -1"
BRANCH_NAME_DEV='dev'
BRANCH_NAME_RELEASE_prefix='release-'
BRANCH_NAME_MASTER='master'
FILE_VERSION_NAME='VERSION' #file that contain last tagged version -> ie: '1.2.3'
FILE_CHANGELOG_NAME='CHANGES' #file that contain changelog


########  INITIALIZE COMMON VARIABLES
NEXT_RELEASE_VERSION=""
EXECUTE_MAJOR_UPDATE=""
menuChoice=""


while [[ $# > 0 ]]
do
key="$1"
case $key in
    start)
      menuChoice="do_start"
    ;;
    end)
      menuChoice="do_end"
    ;;
    patch)
      menuChoice="do_patch"
    ;;
    --debug)
      set -x
    ;;
    --major)
      EXECUTE_MAJOR_UPDATE="yes"
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done


########  COMMON FUNCTIONS
assertCorrectVersionFormat(){
  version=$1
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo '[FATAL ERROR] failed to check app version format , version = '$version
    exit 1
  }
}

assertEverythingHasBeenCommitted(){
  [[ -z $(git status -s) ]] || {
    echo 'fatal error, uncommitted changes cannot initiate release branch, please commit before starting..'
    exit 1
  }
}

validateGitPath(){
  [ -d "${1}/.git" ] || {
    echo 'wrong expected path, this script is supposed to run from a subdirectory of main project ) project main path extracted = '$1
    exit 1
  }
}


assertDevBranchIsCurrentBranch(){
  t=$($GIT_CMD_CURRENT_BRANCH)
  [ "${t}x" == "${BRANCH_NAME_DEV}x" ] || {
   echo 'fatal error, current branch should be "'${BRANCH_NAME_DEV}'" but is : '$t
   exit 1
  }
}

assertMasterBranchIsCurrentBranch(){
  t=$($GIT_CMD_CURRENT_BRANCH)
  [ "${t}x" == "${BRANCH_NAME_MASTER}x" ] || {
   echo 'fatal error, current branch should be "'${BRANCH_NAME_MASTER}'" but is : '$t
   exit 1
  }
}

assertDevBranchExist(){
  t=$(git branch --list | egrep '\sdev$' | wc -l)
   [ $t -gt 0 ] || {
   echo 'error, dev branch does not exist!'
   exit 1
   }
}

assertNoReleaseBranchesAlreadyExists(){
t=$(git branch --list | grep $BRANCH_NAME_RELEASE_prefix | wc -l)
 [ $t -lt 1 ] || {
 echo 'error, release branches already exists >>>'$(git branch --list | grep $BRANCH_NAME_RELEASE_prefix)
 exit 1
 }
}

## return content of VERSION file or ask to initialize it, return -> "N.N.N" or exit
get_or_initialize_version(){
    if [ -f "$FILE_VERSION_NAME" ]; then
      cat "$FILE_VERSION_NAME"
    else
      DEFAULT_INIT_VERSION="0.0.0"
      echo "Could not find a VERSION ( ${FILE_VERSION_NAME} ) file" >&2
      read -p "Do you want to create a version file and start from scratch ? will start from = ${DEFAULT_INIT_VERSION} ....  [y]"  RESPONSE
      [[ "$RESPONSE" =~ ^( |y|Y|yes|Yes|YES)$ ]] || {
        echo 'exiting.. you choosed to interrupt the script by not typing yes' >&2
        exit 0
      }
      echo $DEFAULT_INIT_VERSION
    fi
}

## return "N.N.N" incremented from $1 based on $2
grow_version(){
  START=$1
  incr=$2 # Major|Minor|Patch
  BASE_LIST=(`echo $BASE_STRING | tr '.' ' '`)
  V_MAJOR=${BASE_LIST[0]}
  V_MINOR=${BASE_LIST[1]}
  V_PATCH=${BASE_LIST[2]}

  if [ "${incr}" = "Patch" ]; then
    V_PATCH=$((V_PATCH + 1))
  elif [ "${incr}" = "Minor" ]; then
    V_MINOR=$((V_MINOR + 1))
    V_PATCH=0
  elif [ "${incr}" = "Major" ]; then
    V_MAJOR=$((V_MAJOR + 1))
    V_MINOR=0
    V_PATCH=0
  fi
  echo "$V_MAJOR.$V_MINOR.$V_PATCH"
}

git_do_updateVersionFile(){
  versionFilename=$1
  versionFile_content=$2
  echo $versionFile_content > $versionFilename && \
  git add $versionFilename
}
get_existing_release_branch_name(){
  echo $(git branch --list | grep $BRANCH_NAME_RELEASE_prefix | sed 's/[ *]*//' )
}

getContentOfVersionFile(){
  cat $FILE_VERSION_NAME
}

assertReleaseBranchNameMatchContentOfVersionFile(){
  RELEASE_BRANCH_NAME=$(get_existing_release_branch_name)
  VERSION_FILE_CONTENT=$(getContentOfVersionFile)

  [ "${RELEASE_BRANCH_NAME}" = "${BRANCH_NAME_RELEASE_prefix}${VERSION_FILE_CONTENT}" ] || {
    echo 'fatal error, VERSION NOT MATCHING ! VERSION file contain :'$VERSION_FILE_CONTENT' but release branch is : '$RELEASE_BRANCH_NAME' prefis is: '$BRANCH_NAME_RELEASE_prefix
    exit 1
  }
}


assertReleaseHasBeenAlreadyMergedInCurrentBranch(){
 t=$(git branch --no-merge | grep $BRANCH_NAME_RELEASE_prefix | wc -l) ##list branch not merged in master ( grep release- branch )
 [ $t -eq 0 ] || {
  echo 'fatal error, release branch ['$RELEASE_BRANCH_NAME'] should has been merged in [master] branch manually (to manually resolve possible conficts)! please merge and retry.. '
  exit 1
 }
}
updated_changelog_sincePreviousVersion_and_tag(){
  PREVIOUS_TAGGED_VERSION=$(eval $GIT_CMD_PREVIOUS_TAGGED_VERSION)
  VERSION_FILE_CONTENT=$(getContentOfVersionFile)
  tmpfile=$(mktemp)

  echo "Version ${VERSION_FILE_CONTENT}:" > $tmpfile

  [ -z "${PREVIOUS_TAGGED_VERSION}" ] && {
   echo 'this is first tagged version, extracting whole commit history '
   git log --pretty=format:"%cn %h %ci - %s" | grep -v ' Patch Version ' | grep -v 'Updated changelog' >> $tmpfile
  } || {
   echo 'updating commit history since last tagged version ('${PREVIOUS_TAGGED_VERSION}') -> (v'${VERSION_FILE_CONTENT}')'
   git log --pretty=format:"%cn %h %ci - %s" "${PREVIOUS_TAGGED_VERSION}"...HEAD | grep -v ' Patch Version ' | grep -v 'Updated changelog'  >> $tmpfile
  }

  echo "" >> $tmpfile
  echo "" >> $tmpfile
  cat $FILE_CHANGELOG_NAME >> $tmpfile
  mv $tmpfile $FILE_CHANGELOG_NAME
  git add $FILE_CHANGELOG_NAME
  git commit -m "Updated changelog"
  git tag -a -m "Tagging version ${VERSION_FILE_CONTENT}" "v${VERSION_FILE_CONTENT}"
}




do_start(){
  INCR_DESCRIPTION='Minor' #contain description of current increment
  [ -z $EXECUTE_MAJOR_UPDATE ] || INCR_DESCRIPTION='Major'


  ## only one release at time
  assertNoReleaseBranchesAlreadyExists

  assertEverythingHasBeenCommitted


  ### ASSERTION
  assertDevBranchIsCurrentBranch

  LAST_VERSION=$(get_or_initialize_version)
  assertCorrectVersionFormat $LAST_VERSION
  echo "previous version was ${LAST_VERSION}"

  NEXT_VERSION=$(grow_version $LAST_VERSION $INCR_DESCRIPTION)
  assertCorrectVersionFormat $NEXT_VERSION
  echo "next version will be ${NEXT_VERSION}"


  BRANCH_NAME_RELEASE=${BRANCH_NAME_RELEASE_prefix}""$NEXT_VERSION

  git branch $BRANCH_NAME_RELEASE $BRANCH_NAME_DEV
  git checkout $BRANCH_NAME_RELEASE

  echo 'updating VERSION file...'

  git_do_updateVersionFile  $FILE_VERSION_NAME $NEXT_VERSION
  git commit -m "${INCR_DESCRIPTION} Version bump to ${NEXT_VERSION}"

  echo 'now your has been checkout on new release ['$BRANCH_NAME_RELEASE'] branch'
}

do_end(){
  assertEverythingHasBeenCommitted
  assertReleaseBranchNameMatchContentOfVersionFile

  ## ENTER MASTER
  git checkout $BRANCH_NAME_MASTER

  assertReleaseHasBeenAlreadyMergedInCurrentBranch
  RELEASE_BRANCH_NAME=$(get_existing_release_branch_name)
  git merge $RELEASE_BRANCH_NAME
  updated_changelog_sincePreviousVersion_and_tag

  ## TODO ask confirmation if release branch is not pushed remotely ( -d vs -D during deletion )
  git branch -D  $RELEASE_BRANCH_NAME
  git push origin --tags
  echo 'SUCCESS! release executed, current version is v'$(getContentOfVersionFile)

}

do_patch(){
  INCR_DESCRIPTION='Patch' #contain description of current increment
  assertEverythingHasBeenCommitted

  assertMasterBranchIsCurrentBranch

  LAST_VERSION=$(get_or_initialize_version)
  assertCorrectVersionFormat $LAST_VERSION
  echo "previous version was ${LAST_VERSION}"


  LAST_VERSION=$(get_or_initialize_version)
  assertCorrectVersionFormat $LAST_VERSION
  echo "previous version was ${LAST_VERSION}"

  NEXT_VERSION=$(grow_version $LAST_VERSION $INCR_DESCRIPTION)
  assertCorrectVersionFormat $NEXT_VERSION
  echo "next version will be ${NEXT_VERSION}"

  updated_changelog_sincePreviousVersion_and_tag
  echo 'SUCCESS! HOTFIX patch applied , current version is v'$(getContentOfVersionFile)
}



#### EXECUTION :
validateGitPath $GIT_PROJECT_DIR

## RUN MENU CHOICE
$menuChoice