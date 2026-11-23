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

import {
  to = azurerm_role_assignment.state_data_contributor
  id = "${local.sa_id}/providers/Microsoft.Authorization/roleAssignments/d2a9a1c4-12a0-4942-bef5-f9f57efa68bd"
}

import {
  to = azurerm_management_lock.tfstate
  id = "${local.sa_id}/providers/Microsoft.Authorization/locks/lock-tfstate"
}
