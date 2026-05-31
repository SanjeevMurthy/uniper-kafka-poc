terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Resource Group — holds all Azure resources for the POC.
# Separate from the tfstate RG so destroy is safe.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.azure_region
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Virtual Network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# AKS subnet — for the AKS node pool. Azure CNI consumes a lot of IPs;
# the default /24 is comfortable for a single small node pool.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Private Endpoint subnet — separate from AKS so NSGs and policies can
# differ. With azurerm v4, PE network policies are disabled by default.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "private_endpoints" {
  name                 = "pe-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.pe_subnet_prefix]

  private_endpoint_network_policies = "Disabled"
}

# ---------------------------------------------------------------------------
# Private Endpoints to Confluent — one per AZ alias returned by the
# confluent-network module. `is_manual_connection = false` relies on the
# auto-approval provided by `confluent_private_link_access` (azure subscription
# is allow-listed there).
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "confluent" {
  for_each = toset(var.zones)

  name                = "${var.project_name}-pe-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                              = "${var.project_name}-psc-${each.key}"
    is_manual_connection              = false
    private_connection_resource_alias = var.private_link_service_aliases[each.key]
  }
}

# ---------------------------------------------------------------------------
# Private DNS Zone — name MUST match the Confluent-assigned DNS domain.
# Without this zone, Kafka clients resolve the bootstrap endpoint to a
# public IP and Private Link is bypassed.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "confluent" {
  name                = var.confluent_dns_domain
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Link the DNS zone to the VNet so pods in any subnet of the VNet resolve
# the zone's records. Without this link, the zone exists but has no effect.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "confluent" {
  name                  = "${var.project_name}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.confluent.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# ---------------------------------------------------------------------------
# Wildcard A records — one per zone subdomain pointing at the corresponding
# Private Endpoint's NIC private IP. Confluent's bootstrap server returns
# zone-prefixed FQDNs (e.g. e-az1.lkc-xxx.westeurope.azure.privatelink.confluent.cloud);
# the *.<zone> wildcard catches them.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_a_record" "confluent" {
  for_each = azurerm_private_endpoint.confluent

  name                = "*.${each.key}"
  zone_name           = azurerm_private_dns_zone.confluent.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 60
  records             = [each.value.private_service_connection[0].private_ip_address]
  tags                = var.tags
}
