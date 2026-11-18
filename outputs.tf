output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "container_app_name" {
  value = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  value = local.fqdn
}

output "container_registry_name" {
  value = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "storage_account_name" {
  value = azurerm_storage_account.media.name
}

output "postgres_server_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_db_name" {
  value = azurerm_postgresql_flexible_server_database.main.name
}

output "postgres_admin_login" {
  value = var.postgres_admin_login
}

output "postgres_admin_password" {
  value     = random_password.postgres_admin.result
  sensitive = true
}
