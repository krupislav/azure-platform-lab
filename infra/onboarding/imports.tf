# dev was built by hand on Nov 24; these blocks take it over.
# Written for "dev" only (not for_each): a new environment has nothing to import,
# Terraform simply creates it.
#
# Not imported on purpose: the two Key Vault roles on the VAULT (yesterday's).
# The code now gives them on the RESOURCE GROUP, which is a different scope,
# so Terraform creates 2 new ones. After apply, remove the 2 old vault-scope
# assignments by hand (Key Vault > Access control (IAM)).

locals {
  sub    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  dev_rg = "${local.sub}/resourceGroups/rg-dev-cc"
  dev_id = "${local.dev_rg}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-github-dev"
}

import {
  to = azurerm_resource_group.env["dev"]
  id = local.dev_rg
}

import {
  to = azurerm_user_assigned_identity.github["dev"]
  id = local.dev_id
}

import {
  to = azurerm_federated_identity_credential.pr["dev"]
  id = "${local.dev_id}/federatedIdentityCredentials/fc-pr"
}

import {
  to = azurerm_federated_identity_credential.env["dev"]
  id = "${local.dev_id}/federatedIdentityCredentials/fc-env-dev"
}

import {
  to = azurerm_role_assignment.github_contributor["dev"]
  id = "${local.dev_rg}/providers/Microsoft.Authorization/roleAssignments/7c42e1df-9e1a-47aa-bfda-ebaf4ce58afa"
}

import {
  to = azurerm_role_assignment.github_network["dev"]
  id = "${local.sub}/resourceGroups/rg-hub-cc/providers/Microsoft.Authorization/roleAssignments/477c4f88-6a93-4ad9-ae5a-f40ec72725a6"
}

# Format: <group object ID>/member/<member object ID>
import {
  to = azuread_group_member.github_tfstate["dev"]
  id = "5bb6bfc9-d347-4d5a-8714-d83266f564b6/member/953067a0-8824-4367-b428-87faebad584b"
}

import {
  to = azuread_group.kv_admins["dev"]
  id = "/groups/1aafda39-8307-4f39-a66c-c14b181bcbd8"
}

import {
  to = azuread_group.kv_readers["dev"]
  id = "/groups/8ce014b2-7ca3-451f-b501-f41157339b58"
}
