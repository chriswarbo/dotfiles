#!/usr/bin/env bash
set -e

export EDITOR=emacsclient
if [[ "x$1" = "xclose" ]]
then
    shift
    # Shortcut to close the given Artemis issue ID

    [[ "$#" -eq 1 ]] || {
        echo "artemis-close requires (prefix of) an issue ID. Open issues:" 1>&2
        artemis list 1>&2
        exit 1
    }

    exec artemis add "$1" -p state=resolved -p resolution=fixed
fi

exec git artemis "$@"
