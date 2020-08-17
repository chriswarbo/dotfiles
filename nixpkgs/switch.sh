#!/bin/sh
set -e
set -o pipefail

NIX_PATH=$(nix-instantiate --read-write-mode --eval \
               -E '(import ./nixPath.nix).string'   |
               sed -e 's/^"//g' -e 's/"$//g')
export NIX_PATH
exec darwin-rebuild switch --show-trace
