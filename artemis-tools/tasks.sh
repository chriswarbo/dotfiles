#!/usr/bin/env bash
set -e
ag "FIXME" || true
ag "TODO"  || true
artemis list
