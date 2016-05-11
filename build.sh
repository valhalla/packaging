#!/bin/bash
set -e

VERSION=$(cat version)
RELEASES=( $(cat releases) )
source /etc/lsb-release
PACKAGE="$(if [[ "${1}" == "--versioned-name" ]]; then echo libvalhalla${VERSION}; else echo libvalhalla; fi)"

#get a bunch of stuff we'll need to  make the packages
sudo apt-get install -y git dh-make dh-autoreconf bzr-builddeb pbuilder ubuntu-dev-tools debootstrap devscripts

#get prime_server code into the form bzr likes
git clone --branch ${VERSION} --recursive  https://github.com/kevinkreiser/prime_server.git ${PACKAGE}
pushd ${PACKAGE}
echo -e "libvalhalla (${VERSION}-0ubuntu1~${RELEASES[0]}1) ${RELEASES[0]}; urgency=low\n" > ../debian/changelog
git log --pretty="  * %s" --no-merges $(git tag | grep -FB1 ${VERSION} | head -n 1)..${VERSION} >> ../debian/changelog
echo -e "\n -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -u +"%a, %d %b %Y %T %z")" >> ../debian/changelog
find -name .git | xargs rm -rf
popd
tar pczf ${PACKAGE}_${VERSION}.orig.tar.gz ${PACKAGE}
rm -rf ${PACKAGE}

######################################################
#LETS BUILD THE PACKAGE FOR SEVERAL RELEASES
for release in ${RELEASES[@]}; do
	rm -rf ${release}_build
	mkdir ${release}_build
	pushd ${release}_build

	#copy source targz
	cp -rp ../${PACKAGE}_${VERSION}.orig.tar.gz .
	tar pxf ${PACKAGE}_${VERSION}.orig.tar.gz

	#build the dsc and source.change files
	pushd ${PACKAGE}
	cp -rp ../../debian .
	sed -i -e "s/(.*) [a-z]\+;/(${VERSION}-0ubuntu1~${release}1) ${release};/g" debian/changelog
	if [[ "${1}" == "--versioned-name" ]]; then
		sed -i -e "s/prime-server/prime-server${VERSION}/g" -e "s/prime-server${VERSION}\([0-9]\+\)/prime-server${VERSION}.\1/g" debian/control debian/changelog
	fi
	debuild -S -uc -sa
	popd

	#make sure we support this release
	if [ ! -e ~/pbuilder/${release}-base.tgz ]; then
		pbuilder-dist ${release} create	
	fi

	#try to build a package for it
	DEB_BUILD_OPTIONS="parallel=$(nproc)" pbuilder-dist ${release} build ${PACKAGE}_${VERSION}-0ubuntu1~${release}1.dsc
	popd
done
######################################################
