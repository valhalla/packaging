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

# OPTIONS
if [[ -z ${1} ]]; then
	IFS=',' read -r -a DISTRIBUTIONS <<< "${DISTRIB_CODENAME}"
else
	IFS=',' read -r -a DISTRIBUTIONS <<< "${1}"
fi
if [[ -z ${2} ]]; then
	IFS=',' read -r -a ARCHITECTURES <<< "amd64"
else
	IFS=',' read -r -a ARCHITECTURES <<< "${2}"
fi

#--hookdir although referenced on the internet doesnt work in pbuilder
#neither do exporting environment variables or any other options so
#we have to make a .pbuilderrc and HOOKDIR= to it blech
echo "HOOKDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/hooks" > ${HOME}/.pbuilderrc

#can only make the source tarballs once, or launchpad will barf on differing timestamps
git clone --branch ${VERSION} --recursive https://github.com/valhalla/valhalla.git libvalhalla
#remove superfluous stuff
rm -rf libvalhalla/test_requests libvalhalla/run_route_scripts libvalhalla/gtfs libvalhalla/docker
cp -rp libvalhalla libvalhalla${VERSION}
tar -pczf libvalhalla_${VERSION}.orig.tar.gz libvalhalla
tar -pczf libvalhalla${VERSION}_${VERSION}.orig.tar.gz libvalhalla${VERSION}

#for every combination of distribution and architecture with and without a pinned version
for DISTRIBUTION in ${DISTRIBUTIONS[@]}; do
for ARCHITECTURE in ${ARCHITECTURES[@]}; do
for with_version in false true; do
	#get valhalla code into the form bzr likes
	target_dir="${DISTRIBUTION}/$(if [[ ${with_version} == true ]]; then echo pinned; else echo unpinned; fi)"
	rm -rf ${target_dir}
	mkdir -p ${target_dir}
	PACKAGE="$(if [[ ${with_version} == true ]]; then echo libvalhalla${VERSION}; else echo libvalhalla; fi)"
	cp -rp ${PACKAGE} ${target_dir}
        cp -rp ${PACKAGE}_${VERSION}.orig.tar.gz ${target_dir}
	
	#build the dsc and source.change files
	cd ${target_dir}/${PACKAGE}
	cp -rp ../../../debian .
	#add the version to the package names
	if [[ ${with_version} == true ]]; then
		echo -e "libvalhalla${VERSION} (${VERSION}-0ubuntu1~${DISTRIBUTION}1) ${DISTRIBUTION}; urgency=medium\n" > debian/changelog
		for p in $(grep -F Package debian/control | sed -e "s/.*: //g"); do
			for ext in .dirs .install; do
				mv debian/${p}${ext} debian/$(echo ${p} | sed -e "s/valhalla/valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}-\1/g")${ext}
			done
		done
		sed -i -e "s/\([b| |\-]\)valhalla/\1valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}-\1/g" debian/control
	#dont add the version to the package names
	else
		echo -e "libvalhalla (${VERSION}-0ubuntu1~${DISTRIBUTION}1) ${DISTRIBUTION}; urgency=medium\n" > debian/changelog
	fi
	#fix the boost version for this release
	sed -i -e "s/BOOST_VERSION/${boost[${DISTRIBUTION}]}/g" debian/control
	#finish off the changelog
	curl https://raw.githubusercontent.com/valhalla/valhalla-docs/master/release-notes.md 2>/dev/null | sed -e "s/^##/*/g" -e "s/^\(.\)/  \1/g" >> debian/changelog
	echo -e "\n -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -u +"%a, %d %b %Y %T %z")" >> debian/changelog

	#newer packages in xenial
	if [ "${DISTRIBUTION}" == "xenial" ]; then
		sed -i -e "s/ libsqlite3/ libsqlite3-mod-spatialite, libsqlite3/g" debian/control
		sed -i -e "s/ libspatialite5/ libspatialite7/g" debian/control
		sed -i -e "s/ libprotobuf8/ libprotobuf9v5/g" debian/control
		sed -i -e "s/ libgeos-3\.4\.2/ libgeos-3.5.0/g" debian/control
		sed -i -e "s/ libgeos-c1/ libgeos-c1v5/g" debian/control
	fi

	#create and sign the stuff we need to ship the package to launchpad or try building it with pbuilder
	debuild -S -uc -sa
	cd -

	#only build the one without the version in the name to save time
	if [[ ${with_version} == false && ${NO_BUILD} != true ]]; then
		#make sure we support this release
		if [ ! -e ~/pbuilder/${DISTRIBUTION}-${ARCHITECTURE}_result ]; then
			pbuilder-dist ${DISTRIBUTION} ${ARCHITECTURE} create
		fi

		#try to build a package for it
		cd ${target_dir}
		DEB_BUILD_OPTIONS="parallel=$(nproc)" pbuilder-dist ${DISTRIBUTION} ${ARCHITECTURE} build ${PACKAGE}_${VERSION}-0ubuntu1~${DISTRIBUTION}1.dsc
		cd -
	fi
done
done
done

#cleanup
rm -rf libvalhalla*
