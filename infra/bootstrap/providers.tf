# How Terraform talks to Azure.
# The subscription ID is NOT written here (public repo). Set it before running:
#   $env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv

provider "azurerm" {
  features {}

  # Keys are off on the state account, so data-plane calls (the container)
  # must use Entra too, not storage keys.
  storage_use_azuread = true
}

# Entra ID. No options needed: it signs in the same way as azurerm (az login)
# and takes the tenant from that session.
provider "azuread" {}

# Who is running Terraform right now (tenant, subscription, object ID).
# Only used for the subscription ID in imports.tf, never as a principal:
# "current" is whoever runs it (you on your PC, a pipeline identity in CI).
data "azurerm_client_config" "current" {}
