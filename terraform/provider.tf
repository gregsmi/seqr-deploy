terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.64.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.31.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "=2.10.1"
    }
  }
}

# Use Azure blob store to manage Terraform state - fill in 
# required fields via -backend-config on terraform init.
terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "helm" {
  kubernetes {
    host                   = module.k8s_cluster.config.host
    cluster_ca_certificate = module.k8s_cluster.config.cluster_ca_certificate
    client_certificate     = module.k8s_cluster.config.client_certificate
    client_key             = module.k8s_cluster.config.client_key
  }
}

provider "kubernetes" {
  host                   = module.k8s_cluster.config.host
  cluster_ca_certificate = module.k8s_cluster.config.cluster_ca_certificate
  client_certificate     = module.k8s_cluster.config.client_certificate
  client_key             = module.k8s_cluster.config.client_key
}