mock_provider "azapi" {
  alias = "mock"
}

mock_provider "azurerm" {
  alias = "mock"
}

mock_provider "modtm" {
  alias = "mock"
}

mock_provider "random" {
  alias = "mock"
}

variables {
  name                              = "des-unit"
  location                          = "eastus"
  resource_group_name               = "rg-unit"
  key_vault_key_id                  = "https://unit.vault.azure.net/keys/unit/00000000000000000000000000000000"
  key_vault_resource_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.KeyVault/vaults/unit"
  enable_telemetry                  = false
  key_vault_role_assignment_enabled = false
  managed_identities = {
    system_assigned = true
  }
}

run "no_lock" {
  command = apply

  providers = {
    azapi   = azapi.mock
    azurerm = azurerm.mock
    modtm   = modtm.mock
    random  = random.mock
  }

  assert {
    condition     = length(azurerm_management_lock.this) == 0
    error_message = "Omitting lock must not create a management lock."
  }
}

run "default_delete_lock" {
  command = apply

  providers = {
    azapi   = azapi.mock
    azurerm = azurerm.mock
    modtm   = modtm.mock
    random  = random.mock
  }

  variables {
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = azurerm_management_lock.this[0].name == "lock-CanNotDelete" && azurerm_management_lock.this[0].notes == "Cannot delete the resource or its child resources."
    error_message = "The existing delete-lock name and notes must remain unchanged."
  }

  assert {
    condition     = azurerm_management_lock.this[0].scope == output.resource_id
    error_message = "The lock must remain scoped to the disk encryption set."
  }
}

run "default_read_only_lock" {
  command = apply

  providers = {
    azapi   = azapi.mock
    azurerm = azurerm.mock
    modtm   = modtm.mock
    random  = random.mock
  }

  variables {
    lock = {
      kind = "ReadOnly"
    }
  }

  assert {
    condition     = azurerm_management_lock.this[0].notes == "Cannot delete or modify the resource or its child resources."
    error_message = "The existing read-only lock notes must remain unchanged."
  }
}

run "key_rotation" {
  command = apply

  providers = {
    azapi   = azapi.mock
    azurerm = azurerm.mock
    modtm   = modtm.mock
    random  = random.mock
  }

  variables {
    auto_key_rotation_enabled = true
  }

  assert {
    condition     = azurerm_disk_encryption_set.this.auto_key_rotation_enabled && azurerm_disk_encryption_set.this.key_vault_key_id == var.key_vault_key_id
    error_message = "Enabling rotation must preserve the consumer's encryption key."
  }
}

run "user_assigned_identity" {
  command = apply

  providers = {
    azapi   = azapi.mock
    azurerm = azurerm.mock
    modtm   = modtm.mock
    random  = random.mock
  }

  variables {
    managed_identities = {
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.ManagedIdentity/userAssignedIdentities/unit"]
    }
  }

  assert {
    condition     = azurerm_disk_encryption_set.this.identity[0].type == "UserAssigned" && azurerm_disk_encryption_set.this.identity[0].identity_ids == var.managed_identities.user_assigned_resource_ids
    error_message = "The user-assigned encryption identity must remain unchanged."
  }
}

run "invalid_kind" {
  command = plan

  providers = {
    azapi   = azapi.mock
    azurerm = azurerm.mock
    modtm   = modtm.mock
    random  = random.mock
  }

  variables {
    lock = {
      kind = "None"
    }
  }

  expect_failures = [var.lock]
}
