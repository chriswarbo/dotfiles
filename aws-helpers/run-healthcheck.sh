#!/usr/bin/env bash
set -e
set -o pipefail

function findHealthchecks {
    jq -r '.items | map(select(.path | contains("healthcheck")) | .id) | .[]'
}

aws apigateway get-resources --rest-api-id "$1" |
    findHealthchecks                            |
    while read -r resource
    do
        echo "Found healthcheck endpoint, checking" 1>&2
        RESULT=$(aws apigateway         \
                     test-invoke-method \
                     --http-method GET  \
                     --rest-api-id "$1" \
                     --resource-id "$resource")
        if [[ -n "$RAW" ]]
        then
            echo "$RESULT"
            echo "---"
            echo "$RESULT" | jq -r '.body' | jq '.'
            echo "---"
            echo "$RESULT" | jq -r '.log'
        else
            echo "$RESULT" | jq -r '.body' | jq '.'
        fi
        echo "$RESULT" | jq -e '.status == 200' > /dev/null
    done
