#!/bin/sh
set -e
set -o pipefail

cd "$(dirname "$(readlink -f "$0")")"

NIX_PATH=$(./nixPath.sh)
export NIX_PATH
exec darwin-rebuild switch --show-trace
