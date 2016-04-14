*bash scripts that help versioning code*

# *gitversioner.sh*  : handle semantic versioning 

    usage (from the directory of the project to manage):
    - `gitversioner.sh  [options] args `
**nb: could be lanunched only from *dev* branch, and stage must be clean ( everything committed )**  

 
available command args   
 
- **`start`** bisect+checkout current *DEV* branch into ->  ReleaseCandidate branch named : "release-$version" 
    ie:
     - **$0 start --major**  = start major version ReleaseCandidate
     - **$0 start **  = start minor version ReleaseCandidate
     
    at this point all Release candidate tests should be executed against this branch, changes could be merged directly
          in *release-$version* (release candidate) branch 
          nb: multiple release candidate branch are not allowed
           
- **`end`** 
        checkout in *release-$version* , assert that $version match the content of **VERSION** file ,
            update changelog file (**CHANGES**) with commits labels,
            close/delete ReleaseCandidate branch which should been already merged in master, and create a tag for the release,
             named : **v$version**
             
     **nb: release branch should be already merged in master ( or exception will be thrown )**
     **nb: now is up to you to push tag to remote origin: *git push origin --tags***
                
- **`patch`**
        to be executed on **master** branch, will increment a patch version (v$major.$minor.$patch) updating **VERSION**
        and changelog file (**CHANGES**) with commits labels  

    **nb: *it is ok to start the project with a patch after the 'first commit'***
  
### optional args:
- `--debug` will set -x in bash ( debugging every command )
- `--major` will set major update in release branch (to be used only with `start`)

### git workflow details
 - `master` <- permanent branch *-> same version that is on production* 
 - `dev` <- permanent branch *-> place where everything gets merged and integration-tested*  
 - `feature-xxx` <- suggested name for features to merge in *dev* 
 - `issue-xxx` <- suggested name for fixes to merge in *dev/release* 
 - `hotfix-xxx` <- suggested name for hotfix to merge in *master* 
 - `release-v$major.$minor.$patch` <- will be created and deleted by gitversioner.sh
  
 - file *CHANGES* contain changelog
 - file *VERSION* contain semantic version (major.minor.patch) ie: `1.2.3`
 


### if something goes wrong..
- merge everything in dev and start delete unsuccessful `release-N.N.N` branch 
- if version tags does not match, fix them (delete them or update VERSION file accordingly) 

# *versionedbuilder.sh*
    Enforce conventions in local distributable and versioned builds
        
## path conventions:
- `./dist/live/` <- build script put everything there
- `./dist_versioned/(live|v.N.N.N|latest[symlink])` <- is the path of versioned builds
- `./dist_versioned/v.N.N.N.bz` +  `./dist_versioned/v.N.N.N.bz.sha512` <- is the path of versioned compressed build
###  usage:
  **from software sources path**
    $0 [--debug,--help] [-v (live|last|N.N.N)] [--build-cmd 'gradle dist']
      
    - all args are optionals ( default will be used )  
    - version can be given without '-v' ie: ( $0 last|live|1.2.3 )
    - **last** > build last version contained **VERSION** in file
    - **live[default]** > build current workspace and put in `./dist/live/` 
    - **1.3.9** > checkout given version tag, build in versioned path, and return  
    
    p.s: a temp branch named *tempbranch_build_v* is created during execution
    **nb:**
        - destination build paths must exists and placed in **.gitignore**
        
breaking conventions args : 
  
- --compress|--no-compress  > force compression choices [default: 'yes for versioned, no for live' ]  
- --curbuild-dest  > where the build command place the build [default: 'dist/live' ]  
- --versioned-dest  > where to put versioned distributables [default: 'dist_versioned' ]  
