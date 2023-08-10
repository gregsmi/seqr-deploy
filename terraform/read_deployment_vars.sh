# Load variables we need from a .env file if specified. Sourcing it as a script.
if [[ -f deployment.env ]]; then
  source "deployment.env"
fi

# Check required variables.
if [[ -z "$AAD_TENANT" ]]; then
  err "Missing variable AAD_TENANT (specify via environment or '.env' file)"
fi
if [[ -z "$AZURE_SUBSCRIPTION" ]]; then
  err "Missing variable AZURE_SUBSCRIPTION (specify via environment or '.env' file)"
fi
if [[ -z "$DEPLOYMENT_NAME" ]]; then
  err "Missing variable DEPLOYMENT_NAME (specify via environment or '.env' file)"
fi
if [[ -z "$LOCATION" ]]; then
  err "Missing variable LOCATION (specify via environment or '.env' file)"
fi

RESOURCE_GROUP_NAME="${DEPLOYMENT_NAME}-rg"
STORAGE_ACCOUNT="${DEPLOYMENT_NAME}sa"
STATE_CONTAINER="tfstate"
