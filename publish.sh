#!/bin/bash
set -e

VERSION=$(cat version)
RELEASES=( $(cat releases) )

#have to have a branch of the code up there or the packages wont work from the ppa
if [[ "${1}" != "--no-branch" ]]; then
	cd $(find *_${RELEASES[0]} -maxdepth 0 -type d)
	bzr init
	bzr add
	bzr commit -m "Packaging for ${VERSION}-0ubuntu1."
	bzr push --overwrite bzr+ssh://valhalla-routing@bazaar.launchpad.net/~valhalla-routing/+junk/valhalla_${VERSION}-0ubuntu1
	cd -
fi

#sign and push each package to launchpad
for release in ${RELEASES[@]}; do
	debsign ${release}_build/*source.changes
	dput ppa:valhalla-routing/valhalla ${release}_build/*source.changes
done
