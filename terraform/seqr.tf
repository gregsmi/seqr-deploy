# Reads the latest built SEQR version from the state store.
data "external" "seqr_version" {
  program = ["bash", "./get_version.sh"]
  query   = { blob_name = "seqr.version" }
}

# Create the single SEQR container deployment after all prerequisite services.
# Not added until container is built by GH Action so image tag is available.
resource "helm_release" "seqr" {
  count      = data.external.seqr_version.result.version == "" ? 0 : 1
  name       = "seqr"
  repository = "https://broadinstitute.github.io/seqr-helm/"
  chart      = "seqr"
  version    = "0.0.12"
  timeout    = 300

  values = [
    templatefile("templates/seqr.yaml", {
      service_port      = 8000
      fqdn              = local.fqdn
      whitelisted_cidrs = local.whitelisted_cidrs
      pg_host           = module.postgres_db.credentials.host
      pg_user           = module.postgres_db.credentials.username
      es_host           = local.es_nodename
      image_repo        = "${azurerm_container_registry.acr.login_server}/seqr"
      image_tag         = data.external.seqr_version.result.version
      ref_account       = azurerm_storage_account.main.name
    })
  ]

  depends_on = [
    module.postgres_db,
    helm_release.ingress_nginx,
    kubernetes_manifest.clusterissuer_letsencrypt,
    helm_release.elasticsearch,
    helm_release.redis,
  ]
}

# Set up cert-manager ClusterIssuer to use nginx as the solver. Doesn't work if installed
# on first run, see https://github.com/hashicorp/terraform-provider-kubernetes/issues/1917
resource "kubernetes_manifest" "clusterissuer_letsencrypt" {
  count    = data.external.seqr_version.result.version == "" ? 0 : 1
  manifest = yamldecode(file("templates/cluster-issuer.yaml"))
  depends_on = [
    module.k8s_cluster,
    helm_release.cert_manager
  ]
}
