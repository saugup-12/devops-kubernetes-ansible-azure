#!/usr/bin/env bash

set -e

if [ "$AZURE_SUBSCRIPTION_ID" == "" ]; then
    echo "Looks like you did not source azure_creds.env"
    exit 1
fi

ansible-playbook playbook-generate-arm-templates.yml

azure group deployment create -g "$AZURE_RESOURCE_GROUP" -f ./generated-templates/azure/clear-rg.json -m Complete