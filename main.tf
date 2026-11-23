data "azapi_resource" "key_vault" {
  count = var.customer_managed_key != null ? 1 : 0

  resource_id            = var.customer_managed_key.key_vault_resource_id
  type                   = "Microsoft.KeyVault/vaults@2025-05-01"
  response_export_values = ["properties.vaultUri"]
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.10.1"

  enable_telemetry                 = var.enable_telemetry
  location                         = var.location
  lock                             = local.lock
  managed_identities               = var.managed_identities
  role_assignment_definition_scope = azapi_resource.this.id
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.compute_disk_encryption_sets
  body = {
    properties = merge({
      activeKey = merge(var.auto_key_rotation_enabled ? {} : {
        keyUrl = local.key_url
        }, local.key_vault_same_subscription ? {
        sourceVault = {
          id = var.customer_managed_key.key_vault_resource_id
        }
      } : {})
      encryptionType                    = var.encryption_type
      rotationToLatestKeyVersionEnabled = var.auto_key_rotation_enabled
      }, var.federated_client_id == null ? {} : {
      federatedClientId = var.federated_client_id
    })
  }
  ignore_body_changes = length(var.ignore_body_changes.compute_disk_encryption_sets) > 0 ? var.ignore_body_changes.compute_disk_encryption_sets : null
  replace_triggers_refs = [
    "properties.encryptionType",
  ]
  response_export_values = ["properties.activeKey.keyUrl"]
  retry                  = var.retry
  # Let Azure rotate the active version while retaining explicit key-change detection.
  sensitive_body = var.auto_key_rotation_enabled ? {
    properties = {
      activeKey = { keyUrl = local.key_url }
    }
  } : null
  sensitive_body_version = var.auto_key_rotation_enabled ? {
    "properties.activeKey.keyUrl" = sha256(local.key_url)
  } : null
  tags = var.tags

  dynamic "identity" {
    for_each = module.avm_interfaces.managed_identities_azapi == null ? [] : [module.avm_interfaces.managed_identities_azapi]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    precondition {
      condition     = (var.customer_managed_key != null) != (var.managed_hsm_key_id != null)
      error_message = "Supply exactly one of `customer_managed_key` or `managed_hsm_key_id`."
    }
    precondition {
      condition     = var.customer_managed_key == null ? true : var.customer_managed_key.key_version != null
      error_message = "`customer_managed_key.key_version` is required, including when automatic key rotation is enabled."
    }
    precondition {
      condition     = var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0
      error_message = "Configure a system-assigned or user-assigned identity through `managed_identities`."
    }
    precondition {
      condition     = var.customer_managed_key == null ? true : var.customer_managed_key.user_assigned_identity == null ? var.managed_identities.system_assigned : contains(var.managed_identities.user_assigned_resource_ids, var.customer_managed_key.user_assigned_identity.resource_id)
      error_message = "Configure the encryption identity through `managed_identities`: enable system-assigned identity or include `customer_managed_key.user_assigned_identity.resource_id`."
    }
    precondition {
      condition     = !var.key_vault_role_assignment_enabled || (var.customer_managed_key != null && var.managed_identities.system_assigned && (var.customer_managed_key == null ? true : var.customer_managed_key.user_assigned_identity == null))
      error_message = "Automatic Key Vault RBAC requires a system-assigned encryption identity and `customer_managed_key`. For user-assigned identities, access policies, or Managed HSM, set `key_vault_role_assignment_enabled = false` and grant key access externally."
    }
  }
}

resource "azapi_resource" "key_vault_role_assignment" {
  count = var.key_vault_role_assignment_enabled && var.customer_managed_key != null ? 1 : 0

  name      = uuidv5("url", "${var.customer_managed_key.key_vault_resource_id}/${azapi_resource.this.id}/Key Vault Crypto Service Encryption User")
  parent_id = var.customer_managed_key.key_vault_resource_id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = {
      principalId      = one(azapi_resource.this.identity).principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${provider::azapi::parse_resource_id("Microsoft.KeyVault/vaults", var.customer_managed_key.key_vault_resource_id).subscription_id}/providers/Microsoft.Authorization/roleDefinitions/e147488a-f6f5-4113-8e2d-b22465e65bf6"
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  replace_triggers_refs  = ["properties.principalId", "properties.roleDefinitionId"]
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

  lifecycle {
    # AzureRM generated a UUID; preserve it when moving an existing assignment.
    ignore_changes = [name]
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_role_assignments
  body                   = each.value.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property   = true
  replace_triggers_refs  = ["properties.principalId", "properties.roleDefinitionId"]
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

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = module.avm_interfaces.lock_azapi.name
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = module.avm_interfaces.lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
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

  depends_on = [
    azapi_resource.key_vault_role_assignment,
    azapi_resource.role_assignments,
  ]
}

moved {
  from = azurerm_disk_encryption_set.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

moved {
  from = azurerm_role_assignment.this
  to   = azurerm_role_assignment.this[0]
}

moved {
  from = azurerm_role_assignment.this[0]
  to   = azapi_resource.key_vault_role_assignment[0]
}
