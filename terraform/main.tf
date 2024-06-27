# Master resource group for deployment (unmanaged, created by terraform_init.sh)
data "azurerm_resource_group" "rg" {
  name = "${var.deployment_name}-rg"
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.deployment_name}acr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  admin_enabled       = true
  sku                 = "Premium"
}

module "postgres_db" {
  source = "./modules/db"

  resource_group = data.azurerm_resource_group.rg
  server_name    = "seqr-pg"
  subnet_id      = azurerm_subnet.pg_subnet.id
  database_names = ["reference_data_db", "seqrdb"]
}

resource "random_password" "django_key" {
  length  = 22
  special = false
}

locals {
  k8s_node_resource_group_name = "${var.deployment_name}-aks-rg"

  k8s_secrets = {
    # Authorization credentials for accessing storage accounts via abfss.
    hadoop-creds = { "core-site.xml" = local.hadoop_core_site_xml }
    # Well-known secrets to place in k8s for consumption by SEQR service.
    postgres-secrets = { password = module.postgres_db.credentials.password }
    kibana-secrets   = { "elasticsearch.password" = random_password.elastic_password.result }
    seqr-secrets = {
      django_key       = random_password.django_key.result
      seqr_es_password = random_password.elastic_password.result
      # These 3 are imported as SOCIAL_AUTH_AZUREAD_V2_OAUTH2_* in seqr helm values.
      azuread_client_id     = azuread_application.oauth_app.application_id
      azuread_client_secret = azuread_application_password.oauth_app.value
      azuread_tenant_id     = var.tenant_id
    }
    # k8s needs storage account/secret in order to fuse mount blob volumes.
    # These are well-known key names dictated by the AKS blobfuse CSI driver.
    blobstore-secrets = {
      azurestorageaccountname = data.azurerm_storage_account.main.name
      azurestorageaccountkey  = data.azurerm_storage_account.main.primary_access_key
    }
    # Reference secrets for use by the Django reference app within SEQR.
    reference-secrets = {
      sp_client_id     = module.reference_sp.credentials.clientId
      sp_client_secret = module.reference_sp.credentials.clientSecret
      sp_tenant_id     = module.reference_sp.credentials.tenantId
    }
  }
}

module "k8s_cluster" {
  source = "./modules/k8s"

  resource_group           = data.azurerm_resource_group.rg
  node_resource_group_name = local.k8s_node_resource_group_name
  subnet_id                = azurerm_subnet.k8s_subnet.id
  secrets                  = local.k8s_secrets
  min_compute_nodes        = var.elasticsearch_config.compute_nodes
  default_vm_size          = "Standard_D8ads_v5"
}

resource "azurerm_role_assignment" "k8s_to_acr" {
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
  principal_id         = module.k8s_cluster.principal_id
}

# AKS needs Contributor access to the RG hosting the storage 
# account in order to manage blobfuse-mounted volumes.
resource "azurerm_role_assignment" "k8s_to_rg" {
  role_definition_name = "Contributor"
  scope                = data.azurerm_resource_group.rg.id
  principal_id         = module.k8s_cluster.principal_id
}

# Create the redis cache for SEQR to use.
resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"

  set {
    name  = "auth.enabled"
    value = "false"
  }
}

# Identity used for Github Action-based deployment of docker images.
module "ci_cd_sp" {
  source       = "./modules/sp"
  display_name = "${var.deployment_name}-gh-deploy"
  role_assignments = [
    { role = "AcrPush", scope = azurerm_container_registry.acr.id },
    { role = "Storage Blob Data Contributor", scope = data.azurerm_storage_account.main.id },
  ]
}

# Identity used for authenticated pull of reference data.
module "reference_sp" {
  source       = "./modules/sp"
  display_name = "${var.deployment_name}-ref-reader"
  role_assignments = [
    { role = "Storage Blob Data Reader", scope = azurerm_storage_container.reference.resource_manager_id },
  ]
}
