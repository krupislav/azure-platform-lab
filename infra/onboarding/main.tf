# ONBOARDING layer: the pre-environment work, done by the platform admin.
# For each environment it creates an empty resource group plus everything needed
# to work in it: the pipeline identity (GitHub, no secrets), its roles, and the
# access groups. The environment's own pipeline then fills the resource group.
#
# Order: bootstrap -> global -> onboarding (admin) -> envs/<env> (pipeline).
# The pipeline never manages its own permissions: that is why this is a separate
# layer, run by a person with higher rights.

locals {
  location = "canadacentral"

  # One entry per environment. Onboarding a new one (stage, pre-prod, prod)
  # = add its name here, apply, then add infra/envs/<name>.
  environments = toset(["dev"])

  hub_rg_name = "rg-hub-cc" # global layer; spokes' peering + DNS links live here

  # sg-tfstate-admins (bootstrap layer). Object ID = exact, unique key.
  tfstate_admins_group_id = "5bb6bfc9-d347-4d5a-8714-d83266f564b6"

  # GitHub OIDC subject prefix. This repo uses ID-based ("immutable") subjects:
  # owner@ownerID/repo@repoID. Both IDs are public, not secrets.
  github_subject = "repo:krupislav@63015131/azure-platform-lab@1469173614"
}

data "azurerm_resource_group" "hub" {
  name = local.hub_rg_name
}

# ---------- The empty resource group handed to the environment ----------

resource "azurerm_resource_group" "env" {
  for_each = local.environments

  name     = "rg-${each.key}-cc"
  location = local.location
  tags     = { env = each.key }
}

# ---------- Pipeline identity (GitHub Actions -> Azure, no password) ----------

resource "azurerm_user_assigned_identity" "github" {
  for_each = local.environments

  name                = "id-github-${each.key}"
  resource_group_name = azurerm_resource_group.env[each.key].name
  location            = local.location
  tags                = { env = each.key }
}

# GitHub proves who it is with a short-lived token; Azure trusts it only
# when the token's subject matches exactly.

# Any pull request: used by "terraform plan" on PRs.
resource "azurerm_federated_identity_credential" "pr" {
  for_each = local.environments

  name                      = "fc-pr"
  user_assigned_identity_id = azurerm_user_assigned_identity.github[each.key].id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "${local.github_subject}:pull_request"
}

# Only jobs that run in the GitHub environment of the same name:
# used by "terraform apply" (that environment can require an approval).
resource "azurerm_federated_identity_credential" "env" {
  for_each = local.environments

  name                      = "fc-env-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.github[each.key].id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "${local.github_subject}:environment:${each.key}"
}

# Build anything inside its own resource group.
resource "azurerm_role_assignment" "github_contributor" {
  for_each = local.environments

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

# Hub side of the spoke: peering hub -> spoke and the DNS zone links.
resource "azurerm_role_assignment" "github_network" {
  for_each = local.environments

  scope                = data.azurerm_resource_group.hub.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

# Read/write its state file. This is a pipeline identity created by this code,
# not a person, so its membership IS managed here (people's membership is not).
resource "azuread_group_member" "github_tfstate" {
  for_each = local.environments

  group_object_id  = local.tfstate_admins_group_id
  member_object_id = azurerm_user_assigned_identity.github[each.key].principal_id
}

# ---------- Access groups for the environment's Key Vault ----------
# Roles go to groups, people go into groups (membership outside Terraform).
# Scope = the environment's resource group: it exists before the vault does,
# and there is one vault per environment.

resource "azuread_group" "kv_admins" {
  for_each = local.environments

  display_name     = "sg-kv-${each.key}-admins"
  security_enabled = true
}

resource "azuread_group" "kv_readers" {
  for_each = local.environments

  display_name     = "sg-kv-${each.key}-readers"
  security_enabled = true
}

resource "azurerm_role_assignment" "kv_admins" {
  for_each = local.environments

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azuread_group.kv_admins[each.key].object_id
}

resource "azurerm_role_assignment" "kv_readers" {
  for_each = local.environments

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Key Vault Reader"
  principal_id         = azuread_group.kv_readers[each.key].object_id
}
