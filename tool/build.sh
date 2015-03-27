#!/usr/bin/env bash
set -e

pub upgrade
pub build

BUILD_DIR="$(pwd)/build/web"

[ -d "/tmp/badger-site" ] && rm -rf /tmp/badger-site
git clone git@github.com:badger-lang/site.git /tmp/badger-site
pushd /tmp/badger-site
git checkout gh-pages
cp -R ${BUILD_DIR}/* .
git add .
git commit -m "Update Site"
git push origin gh-pages
popd
rm -rf /tmp/badger-site
