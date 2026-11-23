data "azapi_client_config" "current" {}

resource "random_id" "suffix" {
  byte_length = 6
}

resource "time_static" "key" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-des-${random_id.suffix.hex}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = var.resource_types.resources_resource_groups
  body                   = {}
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) > 0 ? var.ignore_body_changes.resources_resource_groups : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "key_vault" {
  location  = var.location
  name      = "kvdes${random_id.suffix.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.keyvault_vaults
  body = {
    properties = {
      tenantId                  = data.azapi_client_config.current.tenant_id
      sku                       = { family = "A", name = "standard" }
      accessPolicies            = []
      enableRbacAuthorization   = true
      enableSoftDelete          = true
      enablePurgeProtection     = true
      softDeleteRetentionInDays = 90
      publicNetworkAccess       = "Disabled"
      networkAcls = {
        bypass              = "AzureServices"
        defaultAction       = "Deny"
        ipRules             = []
        virtualNetworkRules = []
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.keyvault_vaults) > 0 ? var.ignore_body_changes.keyvault_vaults : null
  response_export_values = ["properties.vaultUri"]
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "key_deployment" {
  name      = "disk-encryption-key"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.resources_deployments
  body = {
    properties = {
      mode = "Incremental"
      template = {
        "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
        contentVersion = "1.0.0.0"
        resources = [{
          type       = split("@", var.resource_types.keyvault_vaults_keys)[0]
          apiVersion = split("@", var.resource_types.keyvault_vaults_keys)[1]
          name       = "${azapi_resource.key_vault.name}/disk-encryption"
          tags       = var.tags
          properties = {
            kty     = "RSA"
            keySize = 2048
            keyOps  = ["wrapKey", "unwrapKey"]
            attributes = {
              enabled = true
              exp     = time_static.key.unix + 15552000
            }
          }
        }]
        outputs = {
          keyUriWithVersion = {
            type  = "string"
            value = "[reference(resourceId('Microsoft.KeyVault/vaults/keys', '${azapi_resource.key_vault.name}', 'disk-encryption'), '${split("@", var.resource_types.keyvault_vaults_keys)[1]}', 'Full').properties.keyUriWithVersion]"
          }
        }
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.resources_deployments) > 0 ? var.ignore_body_changes.resources_deployments : null
  response_export_values = ["properties.outputs.keyUriWithVersion.value"]
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

module "des" {
  source = "../../"

  location  = var.location
  name      = "des-${random_id.suffix.hex}"
  parent_id = azapi_resource.resource_group.id
  customer_managed_key = {
    key_vault_resource_id = azapi_resource.key_vault.id
    key_name              = "disk-encryption"
    key_version           = reverse(split("/", azapi_resource.key_deployment.output.properties.outputs.keyUriWithVersion.value))[0]
  }
  enable_telemetry = var.enable_telemetry
  managed_identities = {
    system_assigned = true
  }
}
