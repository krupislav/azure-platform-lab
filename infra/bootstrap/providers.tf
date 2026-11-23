# How Terraform talks to Azure.
# The subscription ID is NOT written here (public repo). Set it before running:
#   $env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv

provider "azurerm" {
  features {}

  # Keys are off on the state account, so data-plane calls (the container)
  # must use Entra too, not storage keys.
  storage_use_azuread = true
}

# Who is running Terraform right now (tenant, subscription, object ID).
# Used so the code never hard-codes IDs.
data "azurerm_client_config" "current" {}
