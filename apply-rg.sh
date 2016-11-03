#!/usr/bin/env bash

set -e

if [ "$AZURE_SUBSCRIPTION_ID" == "" ]; then
    echo "Looks like you did not source azure_creds.env"
    exit 1
fi

ansible-playbook playbook-generate-arm-templates.yml

azure group deployment create -f ./generated-templates/azure/network.json -g $AZURE_RESOURCE_GROUP
azure group deployment create -f ./generated-templates/azure/storage.json -g $AZURE_RESOURCE_GROUP
azure group deployment create -f ./generated-templates/azure/availability-sets.json -g $AZURE_RESOURCE_GROUP
azure group deployment create -f ./generated-templates/azure/bastion.json -g $AZURE_RESOURCE_GROUP
azure group deployment create -f ./generated-templates/azure/masters.json -g $AZURE_RESOURCE_GROUP
azure group deployment create -f ./generated-templates/azure/minions.json -g $AZURE_RESOURCE_GROUP