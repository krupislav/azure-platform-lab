# Subscription comes from $env:ARM_SUBSCRIPTION_ID (not in the public repo).

provider "azurerm" {
  features {}
}

# Used only to build resource IDs in imports.tf.
data "azurerm_client_config" "current" {}
