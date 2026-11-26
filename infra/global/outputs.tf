# What the environment layers (stage, prod) need from the global layer:
# peer to the hub, link the DNS zones, send logs, pull images.

output "hub_resource_group_name" {
  value = azurerm_resource_group.hub.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "private_dns_zone_ids" {
  value = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.shared.id
}

output "acr_id" {
  value = azurerm_container_registry.shared.id
}

output "acr_login_server" {
  value = azurerm_container_registry.shared.login_server
}

# The app CI workflow needs this as its AZURE_CLIENT_ID (stored as a repo secret).
output "github_acr_client_id" {
  value = azurerm_user_assigned_identity.github_acr.client_id
}
