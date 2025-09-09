terraform {
  required_version = "~> 1.9"

  required_providers {


    azapi = {
      source  = "azure/azapi"
      version = ">=1.9.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}


provider "azurerm" {
  features {}
}
## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.1.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}


module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.1"

  location                    = azurerm_resource_group.this.location
  name                        = module.naming.key_vault.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  tenant_id                   = "5709bb5e-e575-4c99-ae8f-b36af76030f1"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false
  sku_name                    = "standard"
}

resource "azurerm_key_vault_key" "example" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  key_type     = "RSA"
  key_vault_id = module.keyvault.resource_id
  name         = "des-example-key"
  key_size     = 2048
}

module "des" {
  source = "../../"

  key_vault_key_id          = azurerm_key_vault_key.example.id
  key_vault_resource_id     = module.keyvault.resource_id
  location                  = azurerm_resource_group.this.location
  name                      = module.naming.disk_encryption_set.name_unique
  resource_group_name       = azurerm_resource_group.this.name
  auto_key_rotation_enabled = true
  enable_telemetry          = var.enable_telemetry
  managed_identities = {
    system_assigned = true
  }
}


