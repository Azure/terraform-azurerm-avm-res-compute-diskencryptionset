output "resource_id" {
  description = "The deployed disk encryption set resource ID."
  value       = module.des.resource_id
}

output "name" {
  description = "The disk encryption set name."
  value       = module.des.name
}

output "key_vault_key_url" {
  description = "The fully versioned encryption key URL."
  value       = module.des.key_vault_key_url
}

output "system_assigned_mi_principal_id" {
  description = "The encryption identity principal ID."
  value       = module.des.system_assigned_mi_principal_id
}
