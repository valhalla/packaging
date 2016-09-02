[![Build Status](https://travis-ci.org/valhalla/packaging.svg?branch=master)](https://travis-ci.org/valhalla/packaging)

What is this?
-------------

Packaging for debian (ubuntu really). Check out `build.sh` to see how we are now packing valhalla into its library, devel and bin packages. It also has links and notes about how to get those packages onto your PPA. Enjoy and thanks!

What should I do?
-----------------

This was based off of the `prime_server` [packaging work](https://github.com/kevinkreiser/ppa-libprime-server) so your best bet is to head over there to see if that has relevant examples to get you up and running.

Environment Setup
-----------------

You need a fingerprint etc to push builds to launchpad, the thing that builds your software and hosts your ppa packages. This is a one time process that you must do to use the scripts referenced below to submit new packages. Try this:

```bash
#RSA is fine, number of bits is fine, 0 for never expires
#Valhalla for the name, valhalla@mapzen.com for the email
#O for okay, enter a memorable password twice
#random prime gen needs more bytes, open another terminal and do: find /
gpg --gen-key

#hook up to launch pad by first sending your public key
gpg --fingerprint valhalla@mapzen.com
#note the public key in the output:
#pub    2048R/PUBLIC_KEY_HERE 2016-08-30
#send the key to ubuntu servers
gpg --send-keys --keyserver keyserver.ubuntu.com PUBLIC_KEY_HERE

#now we need to log into launchpad, so point your browser here:
#https://launchpad.net/~/+editpgpkeys
#paste in the key fingerprint and click import key
#you'll get an email to the email above

#copy the text from -----BEGIN PGP MESSAGE----- although way to and including -----END PGP MESSAGE----- into a text file lets say a.txt
#decrypt it with:
gpg -d a.txt

#notice the last url is a link to enable this key so follow that link

#you'll also want to add your ssh key
#if you dont already have one (usually in: ~/.ssh/id_rsa.pub) or you dont remember its password create an ssh key with
ssh-keygen -t rsa

#then go here: https://launchpad.net/~/+editsshkeys
#and paste the contents of: ~/.ssh/id_rsa.pub into the box and press import key

#you should be clear to submit packages to launchpad now! congrats!
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

set -e
new_tag=1.1.0 #SET YOUR TAG HERE
export REPOS='midgard baldr sif meili skadi mjolnir odin loki thor tyr tools'
mkdir tmp
cd tmp
PKG_CONFIG_PATH=$(for r in ${REPOS}; do echo -n "${PWD}/${r}:"; done)
for r in ${REPOS}; do
  git clone --recursive --quiet --branch master --depth 1 https://github.com/valhalla/${r}.git
  cd $r
  ./autogen.sh
  ./configure --includedir=${PWD} --libdir=${PWD}/.libs CPPFLAGS="-DBOOST_SPIRIT_THREADSAFE -DBOOST_NO_CXX11_SCOPED_ENUMS"
  make test -j
  tag ${new_tag} "Release ${new_tag}"
  cd -
done
cd -
rm -rf tmp
```

Now that all the repos are tagged, we'll want to try to use the build script to simulate builds of valhalla on clean versions of our ubuntu codenames that we support. So what we want to do first is build libvalhalla with a version in it. To do that try this:

```bash
cd packaging
echo ${new_tag} > version
./build.sh --versioned-name
echo $?
```

If the return was non zero scroll back look what test or build item failed and get to work. Retag the repos after you've merge any fixes to master. If it passed. Crack open your 32bit virtual box vm clone this repo and run `local.sh` which will just get the software and build it directly without pbuilder and all the other stuff. If that also had a non zero return stay in your vm and fix whatever precision issue caused the tests to fail.

```bash
cd local_build/libvalhalla
./autogen.sh
./configure CPPFLAGS="-DBOOST_SPIRIT_THREADSAFE -DBOOST_NO_CXX11_SCOPED_ENUMS"
make test -j$(nproc)
#wait for error
#vi src/... until your fixed
cd -
```

When you are done with that retag if needed. Otherwise we are ready to push some builds to launchpad.

To do this there is a script called `publish.sh` which will make a branch of the code and also push the sources etc to the launchpad build servers. For the first versioned named package we do want to push a branch of code, but for the unversioned one we dont need to. Lets push with a branch to start and then make a build without the version to become the default package:

```bash
./publish.sh
./build.sh
./publish.sh --no-branch
```
