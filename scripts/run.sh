#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -x

export UPDATE_URL=https://pwa.fiji-flo.de

mkdir -p workbench
export WORKBENCH=$(realpath workbench)
if [ ! -d $WORKBENCH/.bin ]; then mkdir $WORKBENCH/.bin; fi
export PATH=$WORKBENCH/.bin:$PATH

DIFFERY_LATEST=$(curl -sL https://api.github.com/repos/fiji-flo/differy/releases/latest | jq -r ".tag_name")
DIFFERY_CURRENT=$(differy -V | sed 's/differy /v/')
if [ $DIFFERY_LATEST != $DIFFERY_CURRENT ]
then
	curl -L https://github.com/fiji-flo/differy/releases/latest/download/differy-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C $WORKBENCH/.bin/
fi

cd $WORKBENCH

git clone https://github.com/mdn/yari.git
git clone https://github.com/mdn/content.git
git clone https://github.com/mdn/interactive-examples.git

export CONTENT_ROOT=$WORKBENCH/content
export BUILD_OUT_ROOT=$WORKBENCH/build

mkdir -p $BUILD_OUT_ROOT

cd $WORKBENCH/yari

yarn
yarn prepare-build
yarn build -n


cd $WORKBENCH/interactive-examples

yarn
yarn build

mv docs $BUILD_OUT_ROOT/examples

cd $WORKBENCH/content

export REV=$(git rev-parse --short HEAD)

cd $WORKBENCH

curl -O $UPDATE_URL/update.json

for OLD_REV in $(jq -r -c '.updates[]' update.json)
do
	curl -O $UPDATE_URL/packages/$OLD_REV-checksums.zip
done
curl -O $UPDATE_URL/packages/$(jq -r -c '.latest' update.json)-checksums.zip

differy package $BUILD_OUT_ROOT --rev $REV

cp update.json ${REV}-update.json

aws s3 cp . s3://XXX --recursive --exclude "*" --include "${REV}-*" --include "update.json"