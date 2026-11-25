# What the environment pipeline needs from onboarding.

output "resource_group_names" {
  value = { for k, rg in azurerm_resource_group.env : k => rg.name }
}

# The pipeline logs in with this (GitHub variable AZURE_CLIENT_ID).
# A client ID is an identifier, not a secret.
output "github_client_ids" {
  value = { for k, id in azurerm_user_assigned_identity.github : k => id.client_id }
}
