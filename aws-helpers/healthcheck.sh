#!/usr/bin/env bash
set -e
set -o pipefail

function check {
    aws apigateway get-resources --rest-api-id "$1" |
        findHealthchecks                            |
        while read -r resource
        do
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
}

function findHealthchecks {
    jq -r '.items | map(select(.path | contains("healthcheck")) | .id) | .[]'
}

function getApi {
    api-info "$1" | jq -r --arg name "$1" '.[$name] | .restapis | .[0]'
}

if [[ "$#" -gt 0 ]]
then
    stacks="$@"
else
    stacks=( ProjCrowdingService ProjAuthService )
fi

for stack in "${stacks[@]}"
do
    check "$(getApi "$stack")"
done
