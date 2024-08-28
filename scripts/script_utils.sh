#!/bin/bash

# Make pipelined operations fail out early.
set -o pipefail

# Get the base directories.
DEPLOY_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT_DIR="$(cd "${DEPLOY_SCRIPTS_DIR}/.." && pwd)"

# Read variables from deployment.env file. Exit if file does not exist.
if [[ ! -f "${DEPLOY_ROOT_DIR}"/deployment.env ]]; then
  err "File deployment.env not found. Please create it from template file deployment.template.env."
fi
# shellcheck source=/dev/null
# Read in the required environment variables.
source "${DEPLOY_ROOT_DIR}"/deployment.env

# Error if $AZURE_TENANT or $AZURE_SUBSCRIPTION are not set.
if [[ -z ${AZURE_TENANT} || -z ${AZURE_SUBSCRIPTION} ]]; then
err "AZURE_TENANT and AZURE_SUBSCRIPTION must be set in deployment.env."
fi

# Error if $DEPLOYMENT_NAME or $LOCATION are not set.
if [[ -z ${DEPLOYMENT_NAME} || -z ${LOCATION} ]]; then
err "DEPLOYMENT_NAME and LOCATION must be set in deployment.env."
fi


# ANSI escape codes for coloring.
readonly ANSI_RED="\033[0;31m"
readonly ANSI_GREEN="\033[0;32m"
readonly ANSI_RESET="\033[0;0m"

#######################################
# Print error message and exit
# Arguments:
#   Message to print.
#######################################
err() {
  echo -e "${ANSI_RED}ERROR: $*${ANSI_RESET}" >&2
  exit 1
}

#######################################
# Print success message
# Arguments:
#   Message to print.
success() {
  echo -e "${ANSI_GREEN}$*${ANSI_RESET}"
}

#######################################
# Login to Azure using the specified tenant 
# and set the specified subscription.
# Arguments:
#   ID of a tenant to login to.
#   ID of subscription to set.
#######################################
login_azure() {
  local aad_tenant="$1"
  local az_subscription="$2"

  # Check if already logged in by trying to get an access token with the specified tenant.
  2>/dev/null az account get-access-token --tenant "${aad_tenant}" --output none
  if [[ $? -ne 0 ]] ; then
    echo "Login required to authenticate with Azure."
    echo "Attempting to login to Tenant: ${aad_tenant}"
    az login --output none --tenant "${aad_tenant}"
    if [[ $? -ne 0 ]]; then
      err "Failed to authenticate with Azure"
    fi
  fi

  local -r sub_name=$(az account show --subscription "${az_subscription}" | jq -r .name)
  # Set the subscription so future commands don't need to specify it.
  echo "Setting subscription to $sub_name (${az_subscription})."
  az account set --subscription "${az_subscription}"
}
