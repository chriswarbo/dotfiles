#!/usr/bin/env bash
set -e
shopt -s nullglob

source ~/.profile

NIX_PATH=$(./nixPath.sh) nix-build --show-trace systemPackages.nix

if [[ -e result/Applications ]]
then
  echo "Populating ~/Applications" 1>&2
  for F in ~/Applications/*
  do
    APP=$(basename "$F")
    rm -v ~/Applications/"$APP"
  done
  for F in result/Applications/*
  do
    APP=$(basename "$F")
    ln -vs "$PWD"/result/Applications/"$APP" ~/Applications/"$APP"
  done
fi
