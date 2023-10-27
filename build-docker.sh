#!/bin/bash

# Fail on any error or undefined variable
set -e -o pipefail -u

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

cd "$SCRIPT_DIR"
podman build --no-cache -t gorillastack-autotag-wrapper:local-build .

