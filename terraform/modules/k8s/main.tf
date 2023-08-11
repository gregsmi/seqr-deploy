
resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "aks0"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  node_resource_group = var.node_resource_group_name
  dns_prefix          = "aks0"

  default_node_pool {
    name           = "default"
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = var.subnet_id

    enable_auto_scaling = true

    min_count = 1
    max_count = 5
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
  vm_size               = "Standard_E16-8ds_v5"

  enable_auto_scaling = true
  min_count           = 0
  max_count           = 3

  node_labels = { "seqr.azure/pooltype" = "compute" }
  node_taints = [ "seqr.azure/pooltype=compute:NoSchedule" ]
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
