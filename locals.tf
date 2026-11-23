locals {
  key_url = var.customer_managed_key == null ? var.managed_hsm_key_id : "${trimsuffix(data.azapi_resource.key_vault[0].output.properties.vaultUri, "/")}/keys/${var.customer_managed_key.key_name}/${var.customer_managed_key.key_version == null ? "" : var.customer_managed_key.key_version}"
  key_vault_same_subscription = var.customer_managed_key == null ? false : lower(
    provider::azapi::parse_resource_id("Microsoft.KeyVault/vaults", var.customer_managed_key.key_vault_resource_id).subscription_id
    ) == lower(
    provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).subscription_id
  )
  lock = var.lock == null ? null : {
    kind  = var.lock.kind
    name  = coalesce(var.lock.name, "lock-${var.lock.kind}")
    notes = coalesce(var.lock.notes, var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources.")
  }
}
