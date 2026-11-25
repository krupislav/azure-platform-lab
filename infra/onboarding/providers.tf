# Subscription comes from $env:ARM_SUBSCRIPTION_ID (not in the public repo).
# Run by an ADMIN (you, from your PC): this layer assigns roles and creates
# Entra groups, which the environment pipelines are not allowed to do.

provider "azurerm" {
  features {}
}

provider "azuread" {}

# Used only to build resource IDs in imports.tf.
data "azurerm_client_config" "current" {}
