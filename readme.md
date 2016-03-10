# bash scripts that help versioning code

# usage: 
- `gitversioner.sh start` start release branch  
- `gitversioner.sh end` end release branch  
- `gitversioner.sh patch` handle hotfix  
  
## optional args:
- `--debug` will set -x in bash ( debugging every command )
- `--major` will set major update in release branch (to be used only with `start`)

## `start` description:
```
 create release-N.N.N branch from dev with version update (minor -> x.++.z)
```

## `end` description:
```
release branch should be already merged in master ( or exception will be thrown ), 
 the script will update changelog , tag the master branch, and delete release
```

## `patch` description:
```
update version (patch -> x.y.++), update changelog with commit already merged in master that does not belong 
 to latest tagged version, ***it is ok to start the project with a patch after the 'first commit' ***
```


## if something goes wrong..
```
merge everything in dev and start delete unsuccessful `release-N.N.N` branch
```