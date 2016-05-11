#!/bin/bash
set -e

rm -rf valhalla src proto
mkdir valhalla 
cp -rp valhalla.h valhalla

for p in $(cat dependencies); do
	git clone --branch ${VERSION} --recursive  https://github.com/valhalla/${d}.git
	find ${d} -name .git | xargs rm -rf
	ln -s ${d}/valhalla/${d} valhalla/${d}
done
