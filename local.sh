#!/bin/bash
set -e

#the main place for info on how to do this is here: http://packaging.ubuntu.com/html/index.html
#section 2. launchpad here: http://packaging.ubuntu.com/html/getting-set-up.html
#section 6. packaging here: http://packaging.ubuntu.com/html/packaging-new-software.html

VERSION=$(cat version)
declare -A boost=( ["trusty"]="1.54" ["vivid"]="1.55" ["wily"]="1.58" ["xenial"]="1.58" )

#get the pre install hooks
sudo hooks/D10addppa

#get a bunch of stuff we'll need to  make the packages
sudo apt-get install -y git dh-make dh-autoreconf bzr-builddeb pbuilder debootstrap devscripts distro-info
#get the stuff we need to build the software
sudo apt-get install -y autoconf automake pkg-config libtool make gcc g++ lcov
sudo apt-get install -y $(grep -F Build-Depends debian/control | sed -e "s/(.*),//g" -e "s/,//g" -e "s/^.*://g")

#tell bzr who we are
DEBFULLNAME="valhalla"
DEBEMAIL="valhalla@mapzen.com"
bzr whoami "${DEBFULLNAME} <${DEBEMAIL}>"
source /etc/lsb-release

#versioned package name
PACKAGE="libvalhalla"

######################################################
#SEE IF WE CAN BUILD THE PACKAGE FOR OUR LOCAL RELEASE
rm -rf local_build
mkdir local_build
#get pieces of code into the form bzr likes
./prepare.sh ${VERSION} local_build/${PACKAGE}
pushd local_build
tar pczf ${PACKAGE}.tar.gz ${PACKAGE}
rm -rf ${PACKAGE}

#start building the package, choose l(ibrary) for the type
bzr dh-make ${PACKAGE} ${VERSION} ${PACKAGE}.tar.gz << EOF
l

EOF

#bzr will make you a template to fill out but who wants to do that manually?
rm -rf ${PACKAGE}/debian
cp -rp ../debian ${PACKAGE}
#add the version name to the packages
if [[ "${1}" == "--versioned-name" ]]; then
	echo -e "libvalhalla${VERSION} (${VERSION}-0ubuntu1~${DISTRIB_CODENAME}1) ${DISTRIB_CODENAME}; urgency=medium\n" > ${PACKAGE}/debian/changelog
	for p in $(grep -F Package ${PACKAGE}/debian/control | sed -e "s/.*: //g"); do
		for ext in .dirs .install; do
			mv ${PACKAGE}/debian/${p}${ext} ${PACKAGE}/debian/$(echo ${p} | sed -e "s/valhalla/valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}-\1/g")${ext}
		done
	done
	sed -i -e "s/\([b| ]\)valhalla/\1valhalla${VERSION}/g" -e "s/valhalla${VERSION}\([0-9]\+\)/valhalla${VERSION}-\1/g" ${PACKAGE}/debian/control
#dont add the version name to the packages
else
	echo -e "libvalhalla (${VERSION}-0ubuntu1~${DISTRIB_CODENAME}1) ${DISTRIB_CODENAME}; urgency=medium\n" > ${PACKAGE}/debian/changelog
fi

#fix the boost version for this release
sed -i -e "s/BOOST_VERSION/${boost[${DISTRIB_CODENAME}]}/g" ${PACKAGE}/debian/control

#finish up the changelog
curl https://raw.githubusercontent.com/valhalla/valhalla-docs/master/release-notes.md 2>/dev/null | sed -e "s/^##/*/g" -e "s/^\(.\)/  \1/g" >> ${PACKAGE}/debian/changelog
echo -e "\n -- ${DEBFULLNAME} <${DEBEMAIL}>  $(date -u +"%a, %d %b %Y %T %z")" >> ${PACKAGE}/debian/changelog

#newer dependencies in xenial
if [ "${DISTRIB_CODENAME}" == "xenial" ]; then
	sed -i -e "s/ libsqlite3/ libsqlite3-mod-spatialite, libsqlite3/g" ${PACKAGE}/debian/control
	sed -i -e "s/ libspatialite5/ libspatialite7/g" ${PACKAGE}/debian/control
	sed -i -e "s/ libprotobuf8/ libprotobuf9v5/g" ${PACKAGE}/debian/control
	sed -i -e "s/ libgeos-3\.4\.2/ libgeos-3.5.0/g" ${PACKAGE}/debian/control
	sed -i -e "s/ libgeos-c1/ libgeos-c1v5/g" ${PACKAGE}/debian/control
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

