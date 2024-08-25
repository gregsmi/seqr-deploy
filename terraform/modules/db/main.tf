resource "random_password" "db_root_password" {
  length  = 22
  special = false
}
locals {
  db_root_user = "dbroot"
  default_port = 5433
}

resource "azurerm_postgresql_flexible_server" "server" {
  # Becomes "<name>.?.database.azure.com"
  name                = var.server_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  administrator_login    = local.db_root_user
  administrator_password = random_password.db_root_password.result

  sku_name   = "GP_Standard_D4s_v3"
  storage_mb = 32768
  version    = "12"
  zone       = 1

  # Only accessible via private endpoint
  public_network_access_enabled = false
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  for_each  = toset(var.database_names)
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.server.id
  charset   = "utf8"
  collation = "en_US.utf8"
}

resource "azurerm_private_endpoint" "db_endpoint" {
  name                = "${azurerm_postgresql_flexible_server.server.name}-endpoint"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_postgresql_flexible_server.server.name}-endpoint"
    private_connection_resource_id = azurerm_postgresql_flexible_server.server.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
}
