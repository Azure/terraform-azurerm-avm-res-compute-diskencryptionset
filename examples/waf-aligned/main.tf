data "azapi_client_config" "current" {}

resource "random_id" "suffix" {
  byte_length = 6
}

resource "time_static" "key" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-des-waf-${random_id.suffix.hex}"
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
            keySize = 3072
            keyOps  = ["wrapKey", "unwrapKey"]
            attributes = {
              enabled = true
              exp     = time_static.key.unix + 15552000
            }
            rotationPolicy = {
              attributes = { expiryTime = "P180D" }
              lifetimeActions = [
                {
                  trigger = { timeAfterCreate = "P90D" }
                  action  = { type = "Rotate" }
                },
                {
                  trigger = { timeBeforeExpiry = "P30D" }
                  action  = { type = "Notify" }
                },
              ]
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

resource "azapi_resource" "workspace" {
  location  = var.location
  name      = "law-des-${random_id.suffix.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.operationalinsights_workspaces
  body = {
    properties = {
      sku             = { name = "PerGB2018" }
      retentionInDays = 30
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.operationalinsights_workspaces) > 0 ? var.ignore_body_changes.operationalinsights_workspaces : null
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

resource "azapi_resource" "key_vault_diagnostics" {
  name      = "audit"
  parent_id = azapi_resource.key_vault.id
  type      = var.resource_types.insights_diagnostic_settings
  body = {
    properties = {
      workspaceId = azapi_resource.workspace.id
      logs = [
        {
          categoryGroup   = "audit"
          enabled         = true
          retentionPolicy = { days = 0, enabled = false }
        },
        {
          categoryGroup   = "allLogs"
          enabled         = false
          retentionPolicy = { days = 0, enabled = false }
        },
      ]
      metrics = [{ category = "AllMetrics", enabled = true }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
  response_export_values = []
  retry                  = var.retry

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

  location                  = var.location
  name                      = "des-${random_id.suffix.hex}"
  parent_id                 = azapi_resource.resource_group.id
  auto_key_rotation_enabled = true
  customer_managed_key = {
    key_vault_resource_id = azapi_resource.key_vault.id
    key_name              = "disk-encryption"
    key_version           = reverse(split("/", azapi_resource.key_deployment.output.properties.outputs.keyUriWithVersion.value))[0]
  }
  enable_telemetry = var.enable_telemetry
  lock = {
    kind = "CanNotDelete"
  }
  managed_identities = {
    system_assigned = true
  }
  role_assignments = {
    reader = {
      role_definition_id_or_name = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
      principal_id               = data.azapi_client_config.current.object_id
    }
  }
}
