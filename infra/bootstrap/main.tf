# The Terraform state storage. Built by hand on Nov 23, taken over by Terraform with import.
# Goal of the first plan: "5 to import, 0 to change". Every "~ change" line means
# this code does not match what was clicked in the portal; fix the code, not Azure.

locals {
  location = "canadacentral"
  tags = {
    env = "global" # required by the policy on mg-lab-dev; global = shared by all environments
  }
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate-cc"
  location = local.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                = "sttfstate0"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = local.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GZRS" # 3 zones + copy in Canada East (converted from GRS)
  access_tier              = "Hot"

  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false # no anonymous blob access
  shared_access_key_enabled        = false # no keys: Entra sign-in + data role only
  default_to_oauth_authentication  = true  # portal uses Entra by default
  public_network_access_enabled    = true  # GitHub runners + his PC must reach it; Entra-only
  cross_tenant_replication_enabled = false

  blob_properties {
    versioning_enabled = true # every state write keeps the old version

    delete_retention_policy {
      days = 7 # deleted state file can be restored for 7 days
    }

    container_delete_retention_policy {
      days = 7 # deleted container can be restored for 7 days
    }
  }

  tags = local.tags

  # Terraform refuses any plan that would destroy this account.
  # A second safety net next to the Azure lock below.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# --- Access to the state: roles go to groups, people go into groups ---
# Terraform owns the groups and their roles. WHO is in a group is not managed here:
# membership is an identity process (portal / access request), so joiners and
# leavers never need a code change. Owner alone can't read blobs, so data-plane
# roles are needed.

resource "azuread_group" "tfstate_admins" {
  display_name     = "sg-tfstate-admins"
  security_enabled = true
}

resource "azuread_group" "tfstate_readers" {
  display_name     = "sg-tfstate-readers"
  security_enabled = true
}

# Read/write on the whole account (admins may add containers later).
resource "azurerm_role_assignment" "tfstate_admins" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_group.tfstate_admins.object_id
}

# Read-only, and only the tfstate container (least privilege).
resource "azurerm_role_assignment" "tfstate_readers" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_group.tfstate_readers.object_id
}

# Azure-side protection: nobody (not even Owner or a pipeline) can delete the account
# until the lock is removed on purpose.
resource "azurerm_management_lock" "tfstate" {
  name       = "lock-tfstate"
  scope      = azurerm_storage_account.tfstate.id
  lock_level = "CanNotDelete"
}
