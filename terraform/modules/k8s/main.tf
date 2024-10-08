
resource "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_resource_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  node_resource_group = var.cluster_resource_name
  dns_prefix          = var.cluster_resource_name

  default_node_pool {
    name           = "default"
    vm_size        = var.default_vm_size
    vnet_subnet_id = var.subnet_id
    os_sku         = "AzureLinux"

    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 8

    temporary_name_for_rotation = "tempdefault"
    # Set to default values to avoid spurious node pool updates.
    upgrade_settings {
      node_soak_duration_in_minutes = 0
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  storage_profile {
    blob_driver_enabled = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "compute_pool" {
  name                  = "compute"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  vnet_subnet_id        = var.subnet_id
  vm_size               = var.compute_vm_size
  os_sku                = "AzureLinux"

  auto_scaling_enabled = true
  min_count            = var.min_compute_nodes
  max_count            = 3

  node_labels = { "seqr.azure/pooltype" = "compute" }
  node_taints = ["seqr.azure/pooltype=compute:NoSchedule"]
}

resource "azurerm_kubernetes_cluster_node_pool" "data_pool" {
  name                  = "database"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  vnet_subnet_id        = var.subnet_id
  vm_size               = var.data_vm_size
  os_sku                = "AzureLinux"

  auto_scaling_enabled = true
  min_count            = var.min_data_nodes
  max_count            = 12

  node_labels = { "seqr.azure/pooltype" = "database" }
  node_taints = ["seqr.azure/pooltype=database:NoSchedule"]
}

locals {
  config = {
    host = "https://${azurerm_kubernetes_cluster.cluster.fqdn}"

    cluster_ca_certificate = base64decode(
      azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate
    )
    client_certificate = base64decode(
      azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate
    )
    client_key = base64decode(
      azurerm_kubernetes_cluster.cluster.kube_config[0].client_key
    )

  }
}

provider "kubernetes" {
  host                   = local.config.host
  cluster_ca_certificate = local.config.cluster_ca_certificate
  client_certificate     = local.config.client_certificate
  client_key             = local.config.client_key
}

resource "kubernetes_secret" "secrets" {
  for_each = var.secrets
  metadata {
    name = each.key
  }
  data = each.value
}
