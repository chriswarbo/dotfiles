#!/bin/sh
set -e
set -o pipefail

NIX_PATH=$(./nixPath.sh)
export NIX_PATH
exec darwin-rebuild switch --show-trace
