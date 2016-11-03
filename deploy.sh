#!/usr/bin/env bash

if [ "$AZURE_SUBSCRIPTION_ID" == "" ]; then
    echo "Looks like you did not source azure_creds.env"
    exit 1
fi

# Needed for azure_rm.py
export AZURE_RESOURCE_GROUPS="$AZURE_RESOURCE_GROUP"

ansible-playbook -i ./ansible-contrib/inventory/azure_rm.py playbook-deploy.yml
