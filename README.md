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
#!/bin/bash
function untag() {
	git tag -d ${1}
	git push origin :${1}
}

function tag() {
	git tag -a ${1} -m "${2}"
	git push origin ${1}
}

set -e
new_tag=1.1.0 #SET YOUR TAG HERE
export REPOS='midgard baldr sif meili skadi mjolnir odin loki thor tyr tools'
rm -rf tmp
mkdir tmp
cd tmp
PKG_CONFIG_PATH=$(for r in ${REPOS}; do echo -n "${PWD}/${r}:"; done)
for r in ${REPOS}; do
  git clone --recursive --quiet --branch master --depth 1 https://github.com/valhalla/${r}.git
  cd $r
  ./autogen.sh
  ./configure --includedir=${PWD} --libdir=${PWD}/.libs CPPFLAGS="-DBOOST_SPIRIT_THREADSAFE -DBOOST_NO_CXX11_SCOPED_ENUMS"
  make test -j
  set +e
  untag ${new_tag}
  set -e
  tag ${new_tag} "Release ${new_tag}"
  cd -
done
cd -
```

Now that all the repos are tagged, we'll want to try to use the build script to simulate builds of valhalla on clean versions of our ubuntu codenames that we support. So what we want to do first is build libvalhalla with a version in it. To do that try this:

```bash
cd packaging
echo ${new_tag} > version
git commit -am "new version"
git push origin master
```

This will trigger travis to build the packages for trusty and xenial for both 32bit and 64bit architectures. If one of the permutations fails you can try it yourself by running something like `./package.sh trusty i386` on your own machine. This would build for trusty on a 32bit architecture. Use `amd64` if you want to test 64bit architiectures. This should let you see what is going wrong with the code. If its a test failure and you need to see the test logs you can login to your pbuilder and manually do stuff but I'd just recommend firing up a vm (if you need to test an architecture or distribution that you don't have). **If you made changes PR those, get them merged and go back to the beginning of this process, tagging the repos again yada yada!** Once you've made it here without changing code you are ready to push some builds to launchpad. To do this there is a script called `publish.sh` which will make a branch of the code and also push the sources etc to the launchpad build servers. Anyway, publish it like so:

```bash
./publish.sh trusty,xenial
```

And wait for launchpad to email you. You'll first get an email letting you know whether or not the packages were excepted or rejected. If rejected it will tell you why. If accepted launchpad will build your packages. If they fail you'll get an email, if they pass you'll get no notification.
