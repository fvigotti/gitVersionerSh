# bash scripts that help versioning code

# *gitversioner.sh*

## usage (from the directory of the project to manage): 
- `gitversioner.sh start` start release branch  
- `gitversioner.sh end` end release branch  
- `gitversioner.sh patch` handle hotfix  
  
### optional args:
- `--debug` will set -x in bash ( debugging every command )
- `--major` will set major update in release branch (to be used only with `start`)

### git workflow details
 - `master` <- permanent branch 
 - `dev` <- permanent branch 
 - `feature-xxx` <- suggested name for features to merge in *dev* 
 - `issue-xxx` <- suggested name for fixes to merge in *dev/release* 
 - `hotfix-xxx` <- suggested name for hotfix to merge in *master* 
 - `release-vN.N.N` <- will be created and deleted by gitversioner.sh
  
 - file *CHANGES* contain changelog
 - file *VERSION* contain semantic version (major.minor.patch) ie: `1.2.3`
 
### `start` description:
```
 create release-N.N.N branch from dev with version update (minor -> x.++.z)
```

### `end` description:
```
release branch should be already merged in master ( or exception will be thrown ), 
 the script will update changelog , tag the master branch, and delete release
```

### `patch` description:
update version (patch -> x.y.++), update changelog with commit already merged in master that does not belong   
to latest tagged version, ***it is ok to start the project with a patch after the 'first commit' ***


### if something goes wrong..
- merge everything in dev and start delete unsuccessful `release-N.N.N` branch 
- if version tags does not match, fix them (delete them or update VERSION file accordingly) 

# *versionedbuilder.sh*
Enforce conventions in local distributable and versione builds
- call the script from software sources path

## conventions:
- `./dist/live/` <- build script put everything there
- `./dist_versioned/(live|v.N.N.N|latest[symlink])` <- is the path of versioned builds
- `./dist_versioned/v.N.N.N.bz` +  `./dist_versioned/v.N.N.N.bz.sha512` <- is the path of versioned compressed build
###  usage:  
echo "usage: $0 [--debug,--help] [-v (live|last|N.N.N)] [--build-cmd 'gradle dist']  "  
echo "     - all args are optionals ( default will be used )"  
echo "     - version can be given without '-v' ie: ( $0 last|live|1.2.3 ) "  
echo "##### potentially dangerous args : ( break conventions ) ##### "  
echo " --compress|--no-compress  > force compression choices [default: 'yes for versioned, no for live' ]"  
echo " --curbuild-dest  > where the build command place the build [default: 'dist/live' ] "  
echo " --versioned-dest  > where to put versioned distributables [default: 'dist_versioned' ] "  
