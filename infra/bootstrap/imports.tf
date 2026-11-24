# Import blocks: "this resource already exists in Azure, put it into the state
# under this address instead of creating it". After a successful apply they do nothing
# and can be deleted (or kept as a record of how the layer was taken over).
# The subscription ID comes from the signed-in session, so it is not in the repo.

locals {
  sub   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  sa_id = "${local.sub}/resourceGroups/rg-tfstate-cc/providers/Microsoft.Storage/storageAccounts/sttfstate0"
}

import {
  to = azurerm_resource_group.tfstate
  id = "${local.sub}/resourceGroups/rg-tfstate-cc"
}

import {
  to = azurerm_storage_account.tfstate
  id = local.sa_id
}

import {
  to = azurerm_storage_container.tfstate
  id = "${local.sa_id}/blobServices/default/containers/tfstate"
}

# Nov 24: access moved from users to groups (built in the portal, imported here).
# The old direct user roles were deleted by hand. The lock was deleted too,
# so it has no import block: Terraform creates it again.

import {
  to = azuread_group.tfstate_admins
  id = "/groups/5bb6bfc9-d347-4d5a-8714-d83266f564b6"
}

import {
  to = azuread_group.tfstate_readers
  id = "/groups/e1e24416-2b23-4b0d-b703-34a7292a9c43"
}

import {
  to = azurerm_role_assignment.tfstate_admins
  id = "${local.sa_id}/providers/Microsoft.Authorization/roleAssignments/1d4f639b-38de-41cc-aef1-9beb16c9c79c"
}

import {
  to = azurerm_role_assignment.tfstate_readers
  id = "${local.sa_id}/blobServices/default/containers/tfstate/providers/Microsoft.Authorization/roleAssignments/90ee9b23-47f6-42aa-866c-a745420d3248"
}
