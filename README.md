## Multifish Pipeline


### Pull external modules

* First time
```
git submodule update --init --recursive
```

* Not first time
```
git pull --recurse-submodules
```

### Compile modules
```
mvn -f external-modules/stitching-spark/pom.xml package
```


