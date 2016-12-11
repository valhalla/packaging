#!/bin/bash
set -e

#get all of the packages ready
NO_BUILD=true ./package.sh "${1}"
IFS=',' read -r -a DISTRIBUTIONS <<< "${1}"
VERSION=$(cat version)

#have to have a branch of the code up there or the packages wont work from the ppa
cd ${DISTRIBUTIONS[0]}/unpinned
bzr init
bzr add
bzr commit -m "Packaging for ${VERSION}-0ubuntu1."
bzr push --overwrite bzr+ssh://valhalla-routing@bazaar.launchpad.net/~valhalla-routing/+junk/valhalla_${VERSION}-0ubuntu1
cd -

#sign and push each package to launchpad
for dist in ${DISTRIBUTIONS[@]}; do
	for pin in pinned unpinned; do
		debsign ${dist}/${pin}/*source.changes
		dput ppa:valhalla-routing/valhalla ${dist}/${pin}/*source.changes
	done
done
