#!/usr/bin/env bash
set -e

function stacks {
    aws cloudformation list-stacks |
        jq -r '.StackSummaries | map(
                   select(.StackStatus != "DELETE_COMPLETE") | .StackName
               ) | .[]'
}

function get {
    jq --arg t "$1" \
       'map(select(.ResourceType == $t) | .PhysicalResourceId)'
}

function resources {
    DATA=$(aws cloudformation list-stack-resources --stack-name "$1" |
           jq '.StackResourceSummaries')

    DOMAINS=$(echo "$DATA" | get 'AWS::ApiGateway::DomainName'  )
    APIKEYS=$(echo "$DATA" | get 'AWS::ApiGateway::ApiKey'      )
    USGKEYS=$(echo "$DATA" | get 'AWS::ApiGateway::UsagePlanKey')
    RESTAPI=$(echo "$DATA" | get 'AWS::ApiGateway::RestApi'     )

    jq -n                           \
       --argjson domains "$DOMAINS" \
       --argjson apikeys "$APIKEYS" \
       --argjson usgkeys "$USGKEYS" \
       --argjson restapi "$RESTAPI" \
       --arg     stack   "$1"       \
       '{($stack): {
          "domains"  : $domains,
          "apikeys"  : $apikeys,
          "usagekeys": $usgkeys,
          "restapis" : $restapi
       }}'
}

if [[ "$#" -gt 0 ]]
then
    for stack in "$@"
    do
        resources "$stack"
        sleep 1
    done
else
    for stack in $(stacks)
    do
        resources "$stack"
        sleep 1
    done
fi
