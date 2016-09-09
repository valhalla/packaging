#!/bin/bash
set -e

VERSION=$(cat version)
RELEASES=( $(cat releases) )

#get all of the packages ready
NO_BUILD=true ./package.sh

#have to have a branch of the code up there or the packages wont work from the ppa
cd ${RELEASES[0]}/unpinned
bzr init
bzr add
bzr commit -m "Packaging for ${VERSION}-0ubuntu1."
bzr push --overwrite bzr+ssh://valhalla-routing@bazaar.launchpad.net/~valhalla-routing/+junk/valhalla_${VERSION}-0ubuntu1
cd -

#sign and push each package to launchpad
for release in ${RELEASES[@]}; do
	for pin in pinned unpinned; do
		debsign ${release}/${pin}/*source.changes
		dput ppa:valhalla-routing/valhalla ${release}/${pin}/*source.changes
	done
done
