## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}


provider "azurerm" {
  features {}
}

# Get current client configuration for tenant_id
data "azurerm_client_config" "current" {}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.9.0"

  is_recommended = true
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
  version = "0.9.1"

  location                    = azurerm_resource_group.this.location
  name                        = module.naming.key_vault.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  # Create the key inside the Key Vault module to ensure proper wait for RBAC propagation
  keys = {
    des_example_key = {
      name     = "des-example-key"
      key_type = "RSA"
      key_size = 2048
      key_opts = [
        "decrypt",
        "encrypt",
        "sign",
        "unwrapKey",
        "verify",
        "wrapKey",
      ]
    }
  }
  network_acls = {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
  purge_protection_enabled = false
  # Grant the current service principal Key Vault Crypto Officer role to manage keys
  role_assignments = {
    crypto_officer = {
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }
  sku_name = "standard"
  # Wait for RBAC propagation before creating keys
  wait_for_rbac_before_key_operations = {
    create = "60s"
  }
}

module "des" {
  source = "../../"

  key_vault_key_id      = module.keyvault.keys_resource_ids["des_example_key"].id
  key_vault_resource_id = module.keyvault.resource_id
  location              = azurerm_resource_group.this.location
  name                  = module.naming.disk_encryption_set.name_unique
  resource_group_name   = azurerm_resource_group.this.name
  enable_telemetry      = var.enable_telemetry
  managed_identities = {
    system_assigned = true
  }
}


