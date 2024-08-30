#!/bin/bash

# shellcheck source=/dev/null
# Read in the main deployment variables and utility functions.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/script_utils.sh"

set -e

# Ensure the correct tenant/sub are set.
login_azure "${AZURE_TENANT}" "${AZURE_SUBSCRIPTION}"

terraform -chdir="${DEPLOY_ROOT_DIR}"/terraform apply
