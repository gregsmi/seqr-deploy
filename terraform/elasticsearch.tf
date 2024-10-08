locals {
  es_nodename = "elasticsearch-master"
}

# Create a container for each elastic search node's persistent storage.
resource "azurerm_storage_container" "es_data" {
  count                 = var.k8s_config.data_nodes
  name                  = "es-data-${count.index}"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "private"
}

# Configure each ES blob storage container for volume mounting.
resource "kubernetes_persistent_volume" "es_data" {
  for_each = { for idx, sc in azurerm_storage_container.es_data : idx => sc }

  metadata {
    name = "es-data-volume-${each.key}"
    annotations = {
      "pv.kubernetes.io/provisioned-by" = "blob.csi.azure.com"
    }
  }
  spec {
    capacity = {
      storage = var.k8s_config.data_storage_size
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "azureblob-fuse-premium"
    mount_options                    = ["-o allow_other"]
    persistent_volume_source {
      csi {
        driver        = "blob.csi.azure.com"
        volume_handle = "${data.azurerm_storage_account.main.name}_es_data_${each.key}"
        volume_attributes = {
          # The name of the storage account is stored in blobstore-secrets.
          resourceGroup = data.azurerm_resource_group.rg.name
          containerName = each.value.name
        }
        node_stage_secret_ref {
          name      = "blobstore-secrets"
          namespace = "default"
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "es_data" {
  for_each = { for idx, sc in azurerm_storage_container.es_data : idx => sc }

  metadata {
    # A Statefulset builds volumeClaim names according to the format 
    # <statefulset-name>-<volumeclaimtemplate-name>-<ordinal-index>.
    # If a volumeClaim already exists with the correct name and other specified 
    # attributes, the Statefulset will use it instead of creating a new one.
    # ES uses the node name for both the Statefulset and the VolumeClaimTemplate.
    name = "${local.es_nodename}-${local.es_nodename}-${each.key}"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.k8s_config.data_storage_size
      }
    }
    volume_name        = "es-data-volume-${each.key}"
    storage_class_name = "azureblob-fuse-premium"
  }
}

resource "random_password" "elastic_password" {
  length  = 22
  special = false
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "8.5.1"
  timeout    = 480

  values = [
    templatefile("templates/elastic.yaml", {
      # default user created by chart is 'elastic' (not configurable)
      password     = random_password.elastic_password.result
      storage_size = var.k8s_config.data_storage_size
      replicas     = var.k8s_config.data_nodes
      min_cpu      = var.k8s_config.data_min_cpu
      min_memory   = var.k8s_config.data_min_memory
    })
  ]

  depends_on = [
    module.k8s_cluster,
    kubernetes_persistent_volume.es_data,
    kubernetes_persistent_volume_claim.es_data
  ]
}

resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "8.5.1"

  depends_on = [helm_release.elasticsearch]
}
