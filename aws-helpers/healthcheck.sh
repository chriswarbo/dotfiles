#!/usr/bin/env bash
set -e
set -o pipefail

CODE=0

function check {
    run-healthcheck "$1" || {
        echo "Stack $stack gave non-200 response" 1>&2
        CODE=1
    }
}

if [[ "$#" -gt 0 ]]
then
    for stack in "$@"
    do
        apiid=$(api-info "$1" |
                jq -r --arg name "$1" '.[$name] | .restapis | .[0]')
        check "$apiid"
    done
else
    echo "Fetching list of stacks to check" 1>&2
    api-info |
        jq -c 'map_values(.restapis[0]) |
               to_entries[0]            |
               select(.value != null)'  |
        while read -r ENTRY
        do
            stack=$(echo "$ENTRY" | jq -r '.key'  )
            apiid=$(echo "$ENTRY" | jq -r '.value')
            echo "Checking stack $stack with REST API $apiid" 1>&2
            check "$apiid"
        done
fi

exit "$CODE"
