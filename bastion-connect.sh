#!/bin/sh
set -e

usage(){
    echo "$0 [PROFILE]"
    echo "Connect to a DAS bastion host. PROFILE must match one of your configured AWS profiles AND be a valid DAS environment name"
    echo "Valid environments: staging, uat, production"
}

EXTRA_SSH_ARGS="-o IdentitiesOnly=yes"

AWS_MFA_PROFILE="auth"

# Define the translation between your AWS profile name and the bastion host
profile_bastion_host(){
    case "$1" in
        staging)    printf '%s@%s' ec2-user rp-bastion.das-staging.farm ;;
        uat)        printf '%s@%s' ec2-user rp-bastion.das-uat.farm     ;;
        production) printf '%s@%s' ec2-user rp-bastion.dasintel.io      ;;
    esac
}

# Define any per-env SSH arguments (eg port forwards)
profile_ssh_args(){
    case "$1" in
        #staging)    echo "-L11002:rural-platform-staginginstance2.ck5fkycwnmz5.ap-southeast-2.rds.amazonaws.com:5432" ;;
        staging)    echo "-L11002:rural-platform-staging.cluster-ck5fkycwnmz5.ap-southeast-2.rds.amazonaws.com:5432" ;;
        uat)        echo "-L11004:rural-platform-uat.cluster-c5xeurd7og0r.ap-southeast-2.rds.amazonaws.com:5432 -L17017:10.0.116.248:27017" ;;
        production) echo "-L11003:rural-platform-production.cluster-cjteonpi0tlv.ap-southeast-2.rds.amazonaws.com:5432 -L 27117:localhost:27017" ;;
    esac
}

# For bash-completion
if [ "$1" = "--list-profiles" ]; then
    echo "staging uat production"
    exit 0
fi

PROFILE="$1"
if [ -z "$PROFILE" ]; then usage; exit 1; fi


# Special case for ETL -- Temporary
if [ "$1" = "etl" ]; then

    exit
fi


BASTION_HOST="$(profile_bastion_host "$PROFILE")"
INSTANCE_USER=$(printf '%s' "$(profile_bastion_host "$PROFILE")" | sed -n 's/\([^@]\+\)@\(.*\)/\1/p')
INSTANCE_HOST=$(printf '%s' "$(profile_bastion_host "$PROFILE")" | sed -n 's/\([^@]\+\)@\(.*\)/\2/p')
if [ -z "$INSTANCE_USER" ]; then
    echo "Missing username in bastion host value: $BASTION_HOST" >&2
    exit 1
fi

# Use pubkey from agent
if ! ssh-add -L >/dev/null ; then ssh-add; fi
SSH_PUBLIC_KEY="$(ssh-add -L | head -n1)"

# Setup AWS MFA
aws-mfa --profile "${AWS_MFA_PROFILE:-default}"

set -x

# Update known_hosts
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$INSTANCE_HOST"
ssh-keyscan -t ecdsa "$INSTANCE_HOST" >> "$HOME/.ssh/known_hosts"

INSTANCE_ID=$(aws ec2 describe-instances --filters 'Name=instance-state-name,Values=running' 'Name=tag:Name,Values=*-bastion-'"$PROFILE" --output text --query 'Reservations[*].Instances[*].InstanceId'  --profile "$PROFILE")

aws ec2-instance-connect send-ssh-public-key \
    --profile "$PROFILE" \
    --region ap-southeast-2 \
    --availability-zone ap-southeast-2a \
    --instance-id "$INSTANCE_ID" \
    --instance-os-user "$INSTANCE_USER" \
    --ssh-public-key "$SSH_PUBLIC_KEY"


# Connect
ssh $(profile_ssh_args "$PROFILE") $EXTRA_SSH_ARGS "$BASTION_HOST"

