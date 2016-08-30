#!/bin/bash
set -e

#get a bunch of stuff we'll need to  make the packages
sudo apt-get install -y git dh-make dh-autoreconf bzr bzr-builddeb pbuilder debootstrap devscripts distro-info ubuntu-dev-tools

#boost!!!!!!
declare -A boost=( ["trusty"]="1.54" ["vivid"]="1.55" ["wily"]="1.58" ["xenial"]="1.58" )

#tell bzr who we are
DEBFULLNAME="valhalla"
DEBEMAIL="valhalla@mapzen.com"
bzr whoami "${DEBFULLNAME} <${DEBEMAIL}>"
source /etc/lsb-release

VERSION=$(cat version)
RELEASES=( $(cat releases) )
PACKAGE="$(if [[ "${1}" == "--versioned-name" ]]; then echo libvalhalla${VERSION}; else echo libvalhalla; fi)"

#get valhalla code into the form bzr likes
./prepare.sh ${VERSION} ${PACKAGE}
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
        #add the version to the package names
	if [[ "${1}" == "--versioned-name" ]]; then
		echo -e "libvalhalla${VERSION} (${VERSION}-0ubuntu1~${release}1) ${release}; urgency=medium\n" > debian/changelog
		for p in $(grep -F Package debian/control | sed -e "s/.*: //g"); do
			for ext in .dirs .install; do
				mv debian/${p}${ext} debian/$(echo ${p} | sed -e "s/valhalla/valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}-\1/g")${ext}
			done
		done
		sed -i -e "s/\([b| ]\)valhalla/\1valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}-\1/g" debian/control
	#dont add the version to the package names
	else
		echo -e "libvalhalla (${VERSION}-0ubuntu1~${release}1) ${release}; urgency=medium\n" > debian/changelog
	fi
	#fix the boost version for this release
	sed -i -e "s/BOOST_VERSION/${boost[${release}]}/g" debian/control
	#finish off the changelog
	curl https://raw.githubusercontent.com/valhalla/valhalla-docs/master/release-notes.md 2>/dev/null | sed -e "s/^##/*/g" -e "s/^\(.\)/  \1/g" >> debian/changelog
	echo -e "\n -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -u +"%a, %d %b %Y %T %z")" >> debian/changelog

	#newer sqlite accesses spatialite differently
	if [ "${release}" == "xenial" ]; then
		sed -i -e "s/ libsqlite3/ libsqlite3-mod-spatialite, libsqlite3/g" debian/control
	fi

	#create and sign the stuff we need to ship the package to launchpad or try building it with pbuilder
	debuild -S -uc -sa
	popd

	#make sure we support this release
	if [ ! -e ~/pbuilder/${release}-base.tgz ]; then
		pbuilder-dist ${release} create	
	fi

	#try to build a package for it
	DEB_BUILD_OPTIONS="parallel=$(nproc)" pbuilder-dist ${release} build ${PACKAGE}_${VERSION}-0ubuntu1~${release}1.dsc --hookdir=../hooks
	popd
done
######################################################
