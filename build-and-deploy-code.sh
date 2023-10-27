
#!/bin/bash

# Stop on error or undefined variables
set -e -o pipefail -u

S3_BUCKET="$1"
shift
S3_PATH="$1"
shift

cd /opt/auto-tag/

# Effectively the same as the first portion of "auto-tag/deploy_autotag.sh:update-stacks()"
# ----
# Install code dependencies
npm install

# Effectively the same as "auto-tag/deploy_autotag.sh:build-package()"
# ----
# Build the code
npm run compile
cp package.json lib/
npm install --no-optional --omit=dev --prefix lib/
pushd lib
zip -x\*.zip -qr9 "autotag.zip" -- *
popd

# Effectively the same as "auto-tag/deploy_autotag.sh:upload-package()"
# ----
# Deploy the code to S3
aws s3 cp "lib/autotag.zip" "s3://${S3_BUCKET}/${S3_PATH}"

echo "[SUCCESS]"