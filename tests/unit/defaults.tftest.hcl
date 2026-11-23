mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      output = {
        properties = {
          vaultUri = "https://unit.vault.azure.net/"
        }
      }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = { results = [] }
    }
  }
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Compute/diskEncryptionSets/des-unit"
      output = {
        properties = {
          activeKey = {
            keyUrl = "https://unit.vault.azure.net/keys/unit/00000000000000000000000000000000"
          }
        }
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  name             = "des-unit"
  location         = "eastus"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit"
  enable_telemetry = false
  customer_managed_key = {
    key_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.KeyVault/vaults/unit"
    key_name              = "unit"
    key_version           = "00000000000000000000000000000000"
  }
  managed_identities = {
    system_assigned = true
  }
}

run "defaults_and_key_access" {
  command = apply

  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.body.properties.activeKey.keyUrl == output.key_vault_key_url
    error_message = "The DES must use the caller's parent and fully versioned key."
  }
  assert {
    condition     = length(azapi_resource.lock) == 0 && !azapi_resource.this.body.properties.rotationToLatestKeyVersionEnabled
    error_message = "Optional locks and automatic rotation must remain disabled by default."
  }
  assert {
    condition     = azapi_resource.key_vault_role_assignment[0].parent_id == var.customer_managed_key.key_vault_resource_id && azapi_resource.key_vault_role_assignment[0].body.properties.principalId == output.system_assigned_mi_principal_id
    error_message = "Automatic key access must be scoped to the vault and use the DES identity."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "lock_and_des_rbac" {
  command = apply

  variables {
    lock = {
      kind  = "CanNotDelete"
      notes = "Retain encryption configuration."
    }
    role_assignments = {
      reader = {
        name                       = "11111111-1111-1111-1111-111111111111"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "22222222-2222-2222-2222-222222222222"
        principal_type             = "ServicePrincipal"
      }
    }
  }

  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete" && azapi_resource.lock[0].body.properties.notes == var.lock.notes && azapi_resource.lock[0].parent_id == output.resource_id
    error_message = "The lock must preserve its default name, honor custom notes, and target the DES."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].parent_id == output.resource_id && azapi_resource.role_assignments["reader"].body.properties.principalId == var.role_assignments.reader.principal_id
    error_message = "Standard RBAC must target the DES rather than the encryption vault."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "read_only_lock" {
  command = apply

  variables {
    lock = { kind = "ReadOnly" }
  }

  assert {
    condition     = azapi_resource.lock[0].body.properties.notes == "Cannot delete or modify the resource or its child resources."
    error_message = "Legacy read-only lock notes must be preserved."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "rotation_and_azapi_controls" {
  command = apply

  variables {
    auto_key_rotation_enabled = true
    resource_types = {
      compute_disk_encryption_sets = "Microsoft.Compute/diskEncryptionSets@2025-01-02"
    }
    retry = {
      error_message_regex = ["ScopeLocked"]
      interval_seconds    = 10
    }
    timeouts = {
      create = "45m"
      delete = "10m"
    }
    ignore_body_changes = {
      compute_disk_encryption_sets = ["tags"]
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.rotationToLatestKeyVersionEnabled && !can(azapi_resource.this.body.properties.activeKey.keyUrl) && azapi_resource.this.sensitive_body_version["properties.activeKey.keyUrl"] == sha256("https://unit.vault.azure.net/keys/unit/${var.customer_managed_key.key_version}")
    error_message = "Automatic rotation must not pin Azure's active version, but explicit key changes must remain detectable."
  }
  assert {
    condition     = azapi_resource.this.type == var.resource_types.compute_disk_encryption_sets && azapi_resource.this.retry.interval_seconds == 10 && azapi_resource.this.timeouts.create == "45m" && azapi_resource.key_vault_role_assignment[0].timeouts.delete == "10m"
    error_message = "Consumer API versions, retries and timeouts must reach the DES and satellite resources."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "user_assigned_encryption_identity" {
  command = apply

  variables {
    key_vault_role_assignment_enabled = false
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.ManagedIdentity/userAssignedIdentities/unit"]
    }
    customer_managed_key = {
      key_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.KeyVault/vaults/unit"
      key_name              = "unit"
      key_version           = "00000000000000000000000000000000"
      user_assigned_identity = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.ManagedIdentity/userAssignedIdentities/unit"
      }
    }
  }

  assert {
    condition     = one(azapi_resource.this.identity).type == "UserAssigned" && toset(one(azapi_resource.this.identity).identity_ids) == var.managed_identities.user_assigned_resource_ids && output.system_assigned_mi_principal_id == null && length(azapi_resource.key_vault_role_assignment) == 0
    error_message = "User-assigned encryption must not attempt a system-assigned principal lookup or create automatic vault RBAC."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "managed_hsm" {
  command = apply

  variables {
    customer_managed_key              = null
    managed_hsm_key_id                = "https://unit.managedhsm.azure.net/keys/unit/00000000000000000000000000000000"
    key_vault_role_assignment_enabled = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.activeKey.keyUrl == var.managed_hsm_key_id && !can(azapi_resource.this.body.properties.activeKey.sourceVault) && length(data.azapi_resource.key_vault) == 0
    error_message = "Managed HSM must use the supplied key URL without a Key Vault lookup or sourceVault."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "cross_subscription_vault" {
  command = apply

  variables {
    customer_managed_key = {
      key_vault_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-key/providers/Microsoft.KeyVault/vaults/unit"
      key_name              = "unit"
      key_version           = "00000000000000000000000000000000"
    }
  }

  assert {
    condition     = !can(azapi_resource.this.body.properties.activeKey.sourceVault) && startswith(azapi_resource.key_vault_role_assignment[0].body.properties.roleDefinitionId, "/subscriptions/11111111-1111-1111-1111-111111111111/")
    error_message = "Cross-subscription keys must omit sourceVault and scope role definitions to the vault subscription."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "invalid_parent" {
  command = plan

  variables {
    parent_id = "rg-unit"
  }

  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "invalid_identity_id" {
  command = plan

  variables {
    managed_identities = {
      system_assigned            = true
      user_assigned_resource_ids = ["not-an-arm-id"]
    }
  }

  expect_failures = [var.managed_identities]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "invalid_lock" {
  command = plan

  variables {
    lock = { kind = "None" }
  }

  expect_failures = [var.lock]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "missing_key_version" {
  command = plan

  variables {
    customer_managed_key = {
      key_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.KeyVault/vaults/unit"
      key_name              = "unit"
    }
  }

  expect_failures = [azapi_resource.this]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "invalid_automatic_rbac_identity" {
  command = plan

  variables {
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.ManagedIdentity/userAssignedIdentities/unit"]
    }
  }

  expect_failures = [azapi_resource.this]
  providers = {
    azapi  = azapi
    random = random
  }
}
