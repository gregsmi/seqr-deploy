########################################################################
# For a new deployment, fill in these values and rename to 'set_env.sh'.
########################################################################

# Tenant and subscription in which to create all resources.
AAD_TENANT="<tenant-id>"
AZURE_SUBSCRIPTION="<subscription-id>"
# Master deployment name, used to derive main resource group name (${DEPLOYMENT_NAME}-rg) and
# various other resources. Must be unique across Azure, between 8-16 lowercase characters only.
DEPLOYMENT_NAME="<deployment_name>"
# Azure region (e.g. "eastus").
LOCATION="<region>"

# Derived resource names.
RESOURCE_GROUP_NAME="${DEPLOYMENT_NAME}-rg"
STORAGE_ACCOUNT="${DEPLOYMENT_NAME}sa"
STATE_CONTAINER="tfstate"

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
