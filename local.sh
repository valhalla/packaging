#!/bin/bash
set -e

#the main place for info on how to do this is here: http://packaging.ubuntu.com/html/index.html
#section 2. launchpad here: http://packaging.ubuntu.com/html/getting-set-up.html
#section 6. packaging here: http://packaging.ubuntu.com/html/packaging-new-software.html

VERSION=$(cat version)
RELEASES=$(cat releases)
DEPS=$(cat dependencies)

#get a bunch of stuff we'll need to  make the packages
sudo apt-get install -y dh-make dh-autoreconf bzr-builddeb pbuilder ubuntu-dev-tools debootstrap devscripts
#get the stuff we need to build the software
sudo apt-get install -y autoconf automake pkg-config libtool make gcc g++ lcov

#tell bzr who we are
DEBFULLNAME="Team Valhalla"
DEBEMAIL="valhalla@mapzen.com"
bzr whoami "${DEBFULLNAME} <${DEBEMAIL}>"
source /etc/lsb-release

#versioned package name
PACKAGE="$(if [[ "${1}" == "--versioned-name" ]]; then echo libvalhalla${VERSION}; else echo libvalhalla; fi)"

######################################################
#SEE IF WE CAN BUILD THE PACKAGE FOR OUR LOCAL RELEASE
rm -rf local_build
mkdir local_build
pushd local_build
#get pieces of code into the form bzr likes
mkdir -p ${PACKAGE}
for d in ${DEPS}; do
	#add to the change log while we are at it
	git clone --branch ${VERSION} --recursive  https://github.com/valhalla/${d}.git ${PACKAGE}/${d}
	pushd ${PACKAGE}/${d}
	find -name .git | xargs rm -rf
	popd
done
#TODO: get the makefile in there and other configure fun
tar pczf ${PACKAGE}.tar.gz ${PACKAGE}
rm -rf ${PACKAGE}

#start building the package, choose l(ibrary) for the type
bzr dh-make ${PACKAGE} ${VERSION} ${PACKAGE}.tar.gz << EOF
l

EOF

#bzr will make you a template to fill out but who wants to do that manually?
rm -rf ${PACKAGE}/debian
cp -rp ../debian ${PACKAGE}
echo -e "libvalhalla (${VERSION}-0ubuntu1~${DISTRIB_CODENAME}1) ${DISTRIB_CODENAME}; urgency=low\n" > ${PACKAGE}/debian/changelog
cat ../changelog >> ${PACKAGE}/debian/changelog
echo -e "\n -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -u +"%a, %d %b %Y %T %z")" >> ${PACKAGE}/debian/changelog

if [[ "${1}" == "--versioned-name" ]]; then
	sed -i -e "s/valhalla/valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}.\1/g" ${PACKAGE}/debian/control ${PACKAGE}/debian/changelog
fi

#add the stuff to the bzr repository
pushd ${PACKAGE}
bzr add debian
bzr commit -m "Packaging for ${VERSION}-0ubuntu1."

#build the packages
bzr builddeb -- -us -uc -j$(nproc)
popd
popd
######################################################

