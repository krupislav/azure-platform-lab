# Import blocks: "this already exists in Azure, adopt it into state at this address".
# The subscription ID comes from the signed-in session, so it is not in the repo.

locals {
  sub    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  hub_rg = "${local.sub}/resourceGroups/${local.hub_rg_name}"
  shr_rg = "${local.sub}/resourceGroups/${local.shared_rg_name}"
}

import {
  to = azurerm_resource_group.hub
  id = local.hub_rg
}

import {
  to = azurerm_virtual_network.hub
  id = "${local.hub_rg}/providers/Microsoft.Network/virtualNetworks/${local.hub_vnet_name}"
}

# for_each on an import block: one import per subnet in the map.
import {
  for_each = local.hub_subnets
  to       = azurerm_subnet.hub[each.key]
  id       = "${local.hub_rg}/providers/Microsoft.Network/virtualNetworks/${local.hub_vnet_name}/subnets/${each.key}"
}

import {
  for_each = toset(local.private_dns_zones)
  to       = azurerm_private_dns_zone.this[each.key]
  id       = "${local.hub_rg}/providers/Microsoft.Network/privateDnsZones/${each.key}"
}

import {
  for_each = toset(local.private_dns_zones)
  to       = azurerm_private_dns_zone_virtual_network_link.hub[each.key]
  id       = "${local.hub_rg}/providers/Microsoft.Network/privateDnsZones/${each.key}/virtualNetworkLinks/${local.hub_link_name}"
}

import {
  to = azurerm_resource_group.shared
  id = local.shr_rg
}

import {
  to = azurerm_log_analytics_workspace.shared
  id = "${local.shr_rg}/providers/Microsoft.OperationalInsights/workspaces/${local.law_name}"
}

import {
  to = azurerm_container_registry.shared
  id = "${local.shr_rg}/providers/Microsoft.ContainerRegistry/registries/${local.acr_name}"
}
