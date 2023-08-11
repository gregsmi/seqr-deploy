#!/bin/bash
# This script is used by Terraform to read version files from the deployment state store.
# Latest build version files are stored by GH Action in the same container as the Terraform state.

set -e

source ../set_env.sh

# Script is called by Terraform with the blob_name as an argument.
eval "$(jq -r '@sh "BLOB_NAME=\(.blob_name)"')"

# Get access key for storage account.
SA_ACCESS_KEY=$(az storage account keys list --resource-group ${RESOURCE_GROUP_NAME} \
    --account-name ${STORAGE_ACCOUNT} --subscription ${AZURE_SUBSCRIPTION} | jq -r .[0].value) \
    || err "Failed to get access key for storage account ${STORAGE_ACCOUNT}"

# Proactive check to see if the specified version file exists.
blob_exists=$(az storage blob exists -n ${BLOB_NAME} -c ${STATE_CONTAINER} --account-name ${STORAGE_ACCOUNT} --account-key "${SA_ACCESS_KEY}" | jq .exists)
if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of ${BLOB_NAME} blob in storage account ${STORAGE_ACCOUNT}. Probably a permissions issue."
fi

VERSION=""
if [[ ${blob_exists} != "false" ]]; then
    VERSION=$(az storage blob download  --no-progress -n ${BLOB_NAME} -c ${STATE_CONTAINER} --account-name ${STORAGE_ACCOUNT} --account-key ${SA_ACCESS_KEY})
    if [[ $? -ne 0 ]]; then
        err "Failed to download ${BLOB_NAME}."
    fi
fi

# Return the version as a JSON object.
jq -n --arg version "$VERSION" '{"version":$version}'
