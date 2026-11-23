output "key_vault_key_url" {
  description = "The fully versioned key URL currently used by the disk encryption set."
  value       = azapi_resource.this.output.properties.activeKey.keyUrl
}

output "name" {
  description = "The name of the disk encryption set."
  value       = azapi_resource.this.name
}

output "resource_id" {
  depends_on = [
    azapi_resource.key_vault_role_assignment,
    azapi_resource.role_assignments,
    azapi_resource.lock,
  ]
  description = "The ID of the disk encryption set."
  value       = azapi_resource.this.id
}

output "system_assigned_mi_principal_id" {
  description = "The principal ID of the system-assigned managed identity, or null when it is disabled."
  value       = var.managed_identities.system_assigned ? one(azapi_resource.this.identity).principal_id : null
}
