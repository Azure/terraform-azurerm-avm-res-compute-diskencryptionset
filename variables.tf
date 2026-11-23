variable "location" {
  type        = string
  description = "Azure region where the disk encryption set and telemetry deployment will be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the disk encryption set."
  nullable    = false
}

variable "parent_id" {
  type        = string
  description = "The fully-qualified ARM resource ID of the existing resource group into which the disk encryption set will be deployed."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid Azure resource group resource ID."
  }
}

variable "auto_key_rotation_enabled" {
  type        = bool
  default     = false
  description = "Whether Azure should rotate the disk encryption set to the latest key version. The initial key must still be fully versioned."
  nullable    = false
}

variable "customer_managed_key" {
  type = object({
    key_vault_resource_id = string
    key_name              = string
    key_version           = optional(string, null)
    user_assigned_identity = optional(object({
      resource_id = string
    }), null)
  })
  default     = null
  description = <<DESCRIPTION
The Key Vault key used to encrypt disks. Supply exactly one of this object or `managed_hsm_key_id`.

- `key_vault_resource_id` - The ARM resource ID of the existing Key Vault.
- `key_name` - The name of the existing RSA key.
- `key_version` - The initial key version. Required by Disk Encryption Set, even when automatic rotation is enabled.
- `user_assigned_identity.resource_id` - An optional encryption identity, also supplied through `managed_identities.user_assigned_resource_ids`. Disable automatic Key Vault RBAC and grant access externally when using this identity. Otherwise a system-assigned identity is required.

The vault URI is read from Azure, so sovereign-cloud DNS suffixes are preserved. No key or identity data-plane lookup is performed. The source vault is omitted from the request when it belongs to a different subscription.
DESCRIPTION

  validation {
    condition     = var.customer_managed_key == null || can(provider::azapi::parse_resource_id("Microsoft.KeyVault/vaults", var.customer_managed_key.key_vault_resource_id))
    error_message = "`customer_managed_key.key_vault_resource_id` must be a valid Azure Key Vault resource ID."
  }
  validation {
    condition     = var.customer_managed_key == null || var.customer_managed_key.user_assigned_identity == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", var.customer_managed_key.user_assigned_identity.resource_id))
    error_message = "`customer_managed_key.user_assigned_identity.resource_id` must be a valid user-assigned managed identity resource ID."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "encryption_type" {
  type        = string
  default     = "EncryptionAtRestWithCustomerKey"
  description = "The disk encryption type. Changing this replaces the disk encryption set."
  nullable    = false

  validation {
    condition     = contains(["EncryptionAtRestWithCustomerKey", "EncryptionAtRestWithPlatformAndCustomerKeys", "ConfidentialVmEncryptedWithCustomerKey"], var.encryption_type)
    error_message = "`encryption_type` must be EncryptionAtRestWithCustomerKey, EncryptionAtRestWithPlatformAndCustomerKeys, or ConfidentialVmEncryptedWithCustomerKey."
  }
}

variable "federated_client_id" {
  type        = string
  default     = null
  description = "The multi-tenant application client ID used to access a key in another tenant. Set to `None` to clear an existing value."
}

variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    compute_disk_encryption_sets   = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot-notation paths to ignore on each managed AzAPI resource. Changes take effect only after apply. Configuration for ignored paths is not sent to Azure until the path is removed. Individual list indices are unsupported.

- `authorization_locks` - Paths ignored on the management lock.
- `authorization_role_assignments` - Paths ignored on both DES-scoped and Key Vault role assignments.
- `compute_disk_encryption_sets` - Paths ignored on the disk encryption set.
DESCRIPTION
  nullable    = false
}

variable "key_vault_role_assignment_enabled" {
  type        = bool
  default     = true
  description = "Whether to grant the DES system-assigned encryption identity Key Vault Crypto Service Encryption User on the key vault. Set to false for user-assigned encryption identities, access policies, cross-tenant permissions managed externally, or Managed HSM."
  nullable    = false
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "managed_hsm_key_id" {
  type        = string
  default     = null
  description = "The fully versioned HTTPS key URL in an existing Managed HSM, as an alternative to customer_managed_key. Grant the DES identity HSM key access externally and set key_vault_role_assignment_enabled to false. This is a data-plane URL, not an ARM resource ID."

  validation {
    condition     = var.managed_hsm_key_id == null ? true : can(regex("^https://[^/]+/keys/[^/]+/[^/?#]+$", var.managed_hsm_key_id))
    error_message = "`managed_hsm_key_id` must be a fully versioned HTTPS key URL."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in var.managed_identities.user_assigned_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    compute_disk_encryption_sets   = optional(string, "Microsoft.Compute/diskEncryptionSets@2026-03-02")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by the module.

- `authorization_locks` - Management lock API version.
- `authorization_role_assignments` - API version for DES-scoped and Key Vault role assignments.
- `compute_disk_encryption_sets` - Disk Encryption Set API version.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration for every managed AzAPI resource.

- `error_message_regex` - Error patterns that trigger retries, for example `ScopeLocked`.
- `interval_seconds` - Initial retry interval in seconds.
- `max_interval_seconds` - Maximum retry interval in seconds.

Defaults to null, retaining provider defaults.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the disk encryption set. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Timeouts for every managed AzAPI resource. Each value is a Go duration such as `30m` or `1h`.

- `create` - Create timeout.
- `read` - Read timeout.
- `update` - Update timeout.
- `delete` - Delete timeout.

Defaults to null, retaining provider defaults.
DESCRIPTION
}
