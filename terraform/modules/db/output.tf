output "fqdn" {
  value = azurerm_postgresql_flexible_server.server.fqdn
}
output "credentials" {
  value = {
    host     = azurerm_private_endpoint.db_endpoint.private_service_connection[0].private_ip_address,
    username = "${local.db_root_user}",
    password = random_password.db_root_password.result,
    port     = local.default_port,
  }
}
