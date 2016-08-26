[![Build Status](https://travis-ci.org/valhalla/packaging.svg?branch=master)](https://travis-ci.org/valhalla/packaging)

What is this?
-------------

Packaging for debian (ubuntu really). Check out `build.sh` to see how we are now packing valhalla into its library, devel and bin packages. It also has links and notes about how to get those packages onto your PPA. Enjoy and thanks!

What should I do?
-----------------

This was based off of the `prime_server` [packaging work](https://github.com/kevinkreiser/ppa-libprime-server) so your best bet is to head over there to see if that has relevant examples to get you up and running.

Environment Setup
-----------------

You need a fingerprint etc to push builds to launchpad, the thing that builds your software and hosts your ppa packages. This is a one time process that you must to so that your computer is configured to interact with launchpad in terms of submitting new packages. Try this:

```bash
#TODO
```

libvalhalla builds
------------------

When there's a new version of Valhalla that is ready for release. You'll want to tag all of the repos so that we can make a build from those tags:

```bash
function untag() {
	git tag -d ${1}
	git push origin :${1}
}

function tag() {
	untag ${1}
	git tag -a ${1} -m "${2}"
	git push origin ${1}
}

export REPOS='midgard baldr sif meili skadi mjolnir odin loki thor tyr tools'
for f in ${REPOS}; do cd $f; git checkout master; git fetch; git merge origin/master; cd -; done
for f in ${REPOS}; do cd $f; make test -j; cd -; done
new_tag=1.1.0 #SET YOUR TAG HERE
for r in ${REPOS}; do cd $r; tag ${new_tag} "Release ${new_tag}"; cd -; done
```

Now that all the repos are tagged, we'll want to try to use the build script to simulate builds of valhalla on clean versions of our ubuntu codenames that we support. So what we want to do first is build libvalhalla with a version in it. To do that try this:

```bash
cd packaging
echo ${new_tag} > version
./build.sh --versioned-name
echo $?
```

If the return was non zero scroll back look what test or build item failed and get to work. If it passed. Crack open your 32bit virtual box vm clone this repo and run `build.sh` again. If that also had a non zero return stay in your vm and fix whatever precision issue caused the tests to fail. Otherwise we are ready to push some builds to launchpad.

To do this there is a script called `publish.sh` which will make a branch of the code and also push the sources etc to the launchpad build servers. For the first versioned named package we do want to push a branch of code, but for the unversioned one we dont need to. Lets push with a branch to start and then make a build without the version to become the default package:

```bash
./publish.sh
./build.sh
./publish.sh --no-branch
```
