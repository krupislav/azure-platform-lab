# Which Terraform and provider versions this layer needs, and where its state lives.

terraform {
  required_version = ">= 1.7" # import blocks with for_each need 1.7+

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Same storage as bootstrap, its own file. Each layer = its own state file,
  # so a mistake in one layer can't touch another layer's state.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-cc"
    storage_account_name = "sttfstate0"
    container_name       = "tfstate"
    key                  = "global.tfstate"
    use_azuread_auth     = true
  }
}
