#!/bin/bash

# shellcheck source=/dev/null
# Read in the main deployment variables and utility functions.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/script_utils.sh"

set -e

# Ensure the correct tenant/sub are set.
login_azure "${AZURE_TENANT}" "${AZURE_SUBSCRIPTION}"

# Log in to the Azure Container Registry.
az acr login --name "${DEPLOYMENT_NAME}acr"

image_tag=$(TZ=America/Los_Angeles date +'%y%m%d-%H%M%S')

# Build and push the latest seqr Docker image.
image_name=${DEPLOYMENT_NAME}acr.azurecr.io/seqr:${image_tag}
docker build \
    -f "${DEPLOY_ROOT_DIR}"/seqr/deploy/docker/seqr/Dockerfile \
    -t "${image_name}" \
    "${DEPLOY_ROOT_DIR}"/seqr
docker push "${image_name}"
success Successfully built and pushed latest SEQR Docker image: "${image_name}"

# Upload image_tag to seqr.version text file.
echo ${image_tag} | az storage blob upload --data @- \
    --account-name "${STORAGE_ACCOUNT}" \
    --container-name "${STATE_CONTAINER}" \
    --name seqr.version \
    --overwrite
success Successfully uploaded image tag to seqr.version file.

success Run 'terraform apply' to deploy the image.
