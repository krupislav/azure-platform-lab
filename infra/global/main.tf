# GLOBAL layer: things every environment (stage, prod, dev) shares, created once.
# Built by hand on Nov 23, taken over with import blocks (imports.tf).
# First plan was "13 to import, 0 to change" (1 harmless update: local auth written explicitly).

locals {
  location = "canadacentral"

  # Names in one place: resources AND import blocks read them from here
  # (an import ID can't read the name from the resource it is importing).
  hub_rg_name    = "rg-hub-cc"
  hub_vnet_name  = "vnet-hub-cc"
  hub_link_name  = "link-vnet-hub-cc" # name of the DNS zone -> hub VNet links
  shared_rg_name = "rg-shared-cc"
  law_name       = "log-shared-cc"
  acr_name       = "acrshared0"

  tags = {
    env = "global" # policy on mg-lab-dev requires an env tag
  }

  # Hub subnets: name => address range. Names of the Azure* / Gateway subnets are
  # fixed by Azure (the service refuses any other name).
  hub_subnets = {
    "GatewaySubnet"       = "10.20.0.0/27" # VPN gateway (later)
    "AzureFirewallSubnet" = "10.20.1.0/26" # Azure Firewall (Day 11), must be /26 or bigger
    "AzureBastionSubnet"  = "10.20.2.0/26" # Bastion (Day 7), must be /26 or bigger
    "snet-appgw"          = "10.20.3.0/24" # Application Gateway (Day 7)
  }

  # Private DNS zones for private endpoints. One zone per service, shared by all spokes.
  private_dns_zones = [
    "privatelink.blob.core.windows.net", # blob storage
    "privatelink.vaultcore.azure.net",   # key vault
  ]
}

# ---------- Network (rg-hub-cc) ----------

resource "azurerm_resource_group" "hub" {
  name     = local.hub_rg_name
  location = local.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = local.location
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

# One block, four subnets (for_each over the map above).
resource "azurerm_subnet" "hub" {
  for_each = local.hub_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [each.value]

  # Portal now creates subnets as "private": no hidden default internet outbound.
  # Outbound must go through something you choose (NAT gateway, Firewall, LB).
  # Terraform's default is true, so it must be written down to match.
  default_outbound_access_enabled = false
}

resource "azurerm_private_dns_zone" "this" {
  for_each = toset(local.private_dns_zones)

  name                = each.key
  resource_group_name = azurerm_resource_group.hub.name
  tags                = local.tags
}

# Link each zone to the hub so names resolve inside it. Spoke links come with each
# environment (they belong to the env, not to the hub).
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = azurerm_private_dns_zone.this

  name                  = local.hub_link_name
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false # no auto-registration of VM records
  tags                  = local.tags
}

# ---------- Shared services (rg-shared-cc) ----------

resource "azurerm_resource_group" "shared" {
  name     = local.shared_rg_name
  location = local.location
  tags     = local.tags
}

# One workspace all environments send logs to.
resource "azurerm_log_analytics_workspace" "shared" {
  name                = local.law_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = local.location
  sku                 = "PerGB2018" # Pricing tier
  retention_in_days   = 30          # days (30 = free retention)
  daily_quota_gb      = 1           # GB per day, cost guard for the lab
  tags                = local.tags
}

# One registry: an image is built once and promoted stage -> prod.
resource "azurerm_container_registry" "shared" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = local.location
  sku                 = "Basic"
  admin_enabled       = false # no admin user: identities, not passwords
  tags                = local.tags
}
