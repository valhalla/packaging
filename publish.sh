#!/bin/bash
set -e

VERSION=$(cat version)
RELEASES=( $(cat releases) )
PACKAGE=$(basename $(find ${RELEASES[0]}_build/* -maxdepth 0 -type d))

#disable the tests for the launchpad builds because they fail without the ability to install locales
for release in ${RELEASES[@]}; do
	pushd ${release}_build
	if [ $(grep -cF override_dh_auto_test: ${PACKAGE}/debian/rules) -eq 0 ]; then
		cat >> ${PACKAGE}/debian/rules << EOF

override_dh_auto_test:
	echo Skipping tests..
EOF
		find . -maxdepth 1 -type f | xargs rm -f
		tar pczf ${PACKAGE}_${VERSION}.orig.tar.gz ${PACKAGE}
		pushd ${PACKAGE}
		debuild -S -uc -sa
		popd
	fi
	popd
done

#have to have a branch of the code up there or the packages wont work from the ppa
if [[ "${1}" != "--no-branch" ]]; then
	pushd $(find ${RELEASES[0]}_build/* -maxdepth 0 -type d)
	bzr init
	bzr add
	bzr commit -m "Packaging for ${VERSION}-0ubuntu1."
	bzr push --overwrite bzr+ssh://valhalla-routing@bazaar.launchpad.net/~valhalla-routing/+junk/valhalla_${VERSION}-0ubuntu1
	popd
fi

#sign and push each package to launchpad
for release in ${RELEASES[@]}; do
	debsign ${release}_build/*source.changes
	dput ppa:valhalla-routing/valhalla ${release}_build/*source.changes
done
