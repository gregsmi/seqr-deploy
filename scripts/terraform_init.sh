#!/bin/bash

# shellcheck source=/dev/null
# Read in the main deployment variables and utility functions.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/script_utils.sh"

#######################################
# Print script usage
#######################################
usage() {
  echo "./$(basename $0) -h   --> show usage"
  echo "./$(basename $0) -l   --> login-only - login to appropriate subscription/tenant and exit"
  echo "./$(basename $0) [-c] --> initialize terraform for the local project"
  echo "    -c: create mode --> one-time init of a new project to create root resources"
}

#######################################
# Ensure existence of a Resource Group in Azure.
# Arguments:
#   Name for the Resource Group.
#   Azure location of the Resource Group.
#   True to create Resource Group if it doesn't exist, otherwise error.
#######################################
ensure_resource_group() {
  local resource_group_name="$1"
  local location="$2"
  local create="$3"
  local rg_exists

  echo "Checking if resource group ${resource_group_name} exists..." 
  # When a resource group doesn't exist, the `az group exists` command returns an authorization error.
  rg_exists=$(az group exists -n "${resource_group_name}")
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of resource group ${resource_group_name}. Probably a permissions issue."
  fi

  if [[ ${rg_exists} == "true" ]]; then
    echo "Resource group ${resource_group_name} already exists."
  elif [[ ${create} == "true" ]]; then
    echo "Resource group ${resource_group_name} does not exist - creating..."
    1>/dev/null az group create --name "${resource_group_name}" --location "${location}"
    if [[ $? -ne 0 ]]; then
      err "Failed to create resource group ${resource_group_name}"
    fi
  else
    err "Resource group ${resource_group_name} doesn't exist (run with '-c' for first-time initialization)."
  fi
}

#######################################
# Ensure existence of a Storage Account in Azure.
# Arguments:
#   Name for the Storage Account.
#   Name of the Resource Group.
#   Azure location for the Storage Account.
#   True to create Storage Account if it doesn't exist, otherwise error.
#######################################
ensure_storage_account() {
  local storage_account_name="$1"
  local resource_group_name="$2"
  local location="$3"
  local create="$4"
  local sa_reason

  echo "Checking if storage account ${storage_account_name} exists..."
  # Uses jq to parse the json output and grab the "reason" field. -r for raw so there aren't quotes in the string.
  sa_reason=$(az storage account check-name -n "${storage_account_name}" | jq -r .reason)
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of storage account ${storage_account_name}. Make sure Microsoft.Storage provider is registered."
  fi

  if [[ ${sa_reason} == "AlreadyExists" ]]; then
    echo "Storage account ${storage_account_name} exists."
  elif [[ ${create} == "true" ]]; then
    echo "Storage account ${storage_account_name} does not exist - creating..."
    1>/dev/null az storage account create --name "${storage_account_name}" --resource-group "${resource_group_name}" --location "${location}" --allow-blob-public-access false
    if [[ $? -ne 0 ]]; then
      err "Failed to create storage group ${storage_account_name}"
    fi
  else
    err "Storage account ${storage_account_name} doesn't exist (run with '-c' for first-time initialization)."
  fi
}

#######################################
# Ensure existence of a Storage Container in Azure.
# Arguments:
#   Name for the Storage Container.
#   Name of the Storage Account.
#   True to create Storage Container if it doesn't exist, otherwise error.
#######################################
ensure_storage_container() {
  local container_name="$1"
  local storage_account_name="$2"
  local create="$3"
  local container_exists

  echo "Checking if storage container ${container_name} exists..."
  # User should have "Storage Blob Data Contributor" role.
  # Uses jq to parse the json output and grab the "exists" field.
  container_exists=$(az storage container exists -n "${container_name}" --account-name "${storage_account_name}" --auth-mode login | jq .exists)
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of container ${container_name} in storage account ${storage_account_name}. Probably a permissions issue."
  fi

  if [[ ${container_exists} != "false" ]]; then
      echo "Container ${container_name} exists."
  elif [[ ${create} == "true" ]]; then
      echo "Creating container ${container_name}"
      1>/dev/null az storage container create -n "${container_name}" --account-name "${storage_account_name}" --auth-mode login
      if [[ $? -ne 0 ]]; then
        err "Failed to create storage container ${container_name}"
      fi
      # Wait for storage container to create.
      sleep 5
  else
    err "Container ${container_name} doesn't exist (run with '-c' for first-time initialization)."
  fi
}

# Process options.
while getopts ":hcl" option; do
  case "${option}" in
    h) usage; exit 0;;
    c) create_resources="true";;
    l) login_only="true";;
    ?) echo "Invalid option: -${OPTARG}."; usage; exit 1;;
  esac
done

# shellcheck disable=SC2153
echo "DEPLOYMENT_NAME = $DEPLOYMENT_NAME, LOCATION = $LOCATION"

# Login to Azure using the specified tenant if not already logged in.
# Note, terraform recomments authenticating to az cli manually when running terraform locally,
# see: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity
login_azure "${AZURE_TENANT}" "${AZURE_SUBSCRIPTION}"
if [[ ${login_only} == "true" ]]; then
  success "Successfully logged in - exiting."    
  exit 0
fi
# Create resource group if it doesn't exist.
# shellcheck disable=SC2153
ensure_resource_group "${RESOURCE_GROUP_NAME}" "${LOCATION}" "${create_resources}" || exit
# Create storage account for Terraform state if it doesn't exist.
ensure_storage_account "${STORAGE_ACCOUNT}" "${RESOURCE_GROUP_NAME}" "${LOCATION}" "${create_resources}" || exit
# Create tfstate container to store Terraform state if it doesn't exist.
ensure_storage_container "${STATE_CONTAINER}" "${STORAGE_ACCOUNT}" "${create_resources}" || exit
# Get an access key to the storage account for Terraform state. Use jq to grab the 
# "value" field of the first key. "-r" option gives raw output without quotes.
SA_ACCESS_KEY=$(az storage account keys list --resource-group "${RESOURCE_GROUP_NAME}" \
    --account-name "${STORAGE_ACCOUNT}" --subscription "${AZURE_SUBSCRIPTION}" | jq -r .[0].value) \
    || err "Failed to get access key for storage account ${STORAGE_ACCOUNT}"
success "Deployment infrastructure setup successful - initializing Terraform..."

# Suppress unnecessary interactive text.
export TF_IN_AUTOMATION=true
# Configure Terraform backend (azurerm) to use Azure blob container to 
# store state. This configuration is persisted in local tfstate.
terraform -chdir="${DEPLOY_ROOT_DIR}"/terraform init -reconfigure -upgrade \
  -backend-config="storage_account_name=${STORAGE_ACCOUNT}" \
  -backend-config="container_name=${STATE_CONTAINER}" \
  -backend-config="access_key=${SA_ACCESS_KEY}" \
  -backend-config="key=deploy.tfstate"

# Create/update Terraform variables file.
# Write out new default tfvars file.
cat << EOF > "${DEPLOY_ROOT_DIR}"/terraform/deployment.auto.tfvars.json
{
  "deployment_name": "${DEPLOYMENT_NAME}",
  "location": "$LOCATION",
  "tenant_id": "${AZURE_TENANT}",
  "subscription_id": "${AZURE_SUBSCRIPTION}"
}
EOF

success "Initialization complete - variable file deployment.auto.tfvars.json created/updated."

