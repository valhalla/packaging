#!/bin/bash
set -e

VERSION=$(cat version)

#get all of the packages ready
for dist in ${@}; do
	NO_BUILD=true ./package.sh ${dist}
done

#have to have a branch of the code up there or the packages wont work from the ppa
cd ${1}/unpinned
bzr init
bzr add
bzr commit -m "Packaging for ${VERSION}-0ubuntu1."
bzr push --overwrite bzr+ssh://valhalla-routing@bazaar.launchpad.net/~valhalla-routing/+junk/valhalla_${VERSION}-0ubuntu1
cd -

#sign and push each package to launchpad
for dist in ${@}; do
	for pin in pinned unpinned; do
		debsign ${dist}/${pin}/*source.changes
		dput ppa:valhalla-routing/valhalla ${dist}/${pin}/*source.changes
	done
done
