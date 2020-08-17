#!/bin/sh
set -e
set -o pipefail
nix-instantiate --read-write-mode --eval -E '(import ./nixPath.nix).string' |
    sed -e 's/^"//g' -e 's/"$//g'
