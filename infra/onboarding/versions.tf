# Which Terraform and provider versions this layer needs, and where its state lives.

terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Entra ID (Microsoft Graph): the access groups and the group membership.
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-cc"
    storage_account_name = "sttfstate0"
    container_name       = "tfstate"
    key                  = "onboarding.tfstate"
    use_azuread_auth     = true
  }
}
