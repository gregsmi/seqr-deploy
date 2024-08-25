locals {
  es_nodename = "elasticsearch-master"
}

resource "random_password" "elastic_password" {
  length  = 22
  special = false
}
