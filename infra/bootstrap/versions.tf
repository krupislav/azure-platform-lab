# Which Terraform and which provider versions this code needs,
# and where Terraform keeps its own state.

terraform {
  required_version = ">= 1.6" # import blocks with expressions need 1.6+

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # any 4.x, never 5.x without us choosing it
    }
  }

  # Remote state. The bootstrap layer stores its own state in the account it manages.
  # That works because the account was created by hand first (chicken and egg solved).
  # No secrets here: the account has keys off, so Terraform signs in with Entra (az login).
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-cc"
    storage_account_name = "sttfstate0"
    container_name       = "tfstate"
    key                  = "bootstrap.tfstate" # the file name inside the container
    use_azuread_auth     = true                # Entra instead of storage keys
  }
}
