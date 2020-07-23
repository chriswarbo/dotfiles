#!/usr/bin/env bash
set -e
cd "$HOME"

if [ $# -lt 1 ]
then
    name=$(basename "$0")
    echo "$name: Log in to AWS CLI session, using MFA token" 1>&2
    echo "Example: $name 123456" 1>&2
    exit 2
fi

export AWS_PROFILE=prod

MFA_SERIAL_NUMBER=$(aws iam list-mfa-devices              \
                        --query 'MFADevices[].SerialNumber' \
                        --output text)

PARAMS=( AccessKeyId SecretAccessKey SessionToken )

function paramArg {
    # Turn 'FooBar' into 'aws_foo_bar'
    UNDERSCORED=$(echo "$1"                            |
                  sed -e 's/\([^^]\)\([A-Z]\)/\1_\2/g' |
                  tr '[:upper:]' '[:lower:]'           )
    echo "aws_$UNDERSCORED"
}

# Comma-separate PARAMS
QUERY="Credentials.[$(IFS=, ; echo "${PARAMS[*]}")]"
 DATA=$(aws sts get-session-token              \
            --serial-number "$MFA_SERIAL_NUMBER" \
            --query         "$QUERY"             \
            --output        text                 \
            --token-code    "$1")

for i in "${!PARAMS[@]}"  # Loop through indices, not values
do
    PARAM=$(paramArg "${PARAMS[$i]}")
    VALUE=$(echo "$DATA" | cut -f"$(( i + 1 ))")
    aws configure set "$PARAM" "$VALUE" --profile=mfa
    echo export "$PARAM"="$VALUE"
done

aws configure set region eu-west-2 --profile=mfa

echo "DONE" 1>&2
