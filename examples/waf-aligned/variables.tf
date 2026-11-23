variable "location" {
  type        = string
  description = "The Azure region for this module's resources or telemetry deployment."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "ignore_body_changes" {
  type = object({
    resources_resource_groups      = optional(list(string), [])
    keyvault_vaults                = optional(list(string), [])
    resources_deployments          = optional(list(string), [])
    operationalinsights_workspaces = optional(list(string), [])
    insights_diagnostic_settings   = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot paths ignored for resource groups (resources_resource_groups), vaults (keyvault_vaults), key deployments (resources_deployments), workspaces (operationalinsights_workspaces), and diagnostics (insights_diagnostic_settings). Changes take effect after apply; ignored configuration is not sent to Azure."
  nullable    = false
}

variable "resource_types" {
  type = object({
    resources_resource_groups      = optional(string, "Microsoft.Resources/resourceGroups@2025-04-01")
    resources_deployments          = optional(string, "Microsoft.Resources/deployments@2025-04-01")
    keyvault_vaults                = optional(string, "Microsoft.KeyVault/vaults@2025-05-01")
    keyvault_vaults_keys           = optional(string, "Microsoft.KeyVault/vaults/keys@2025-05-01")
    operationalinsights_workspaces = optional(string, "Microsoft.OperationalInsights/workspaces@2023-09-01")
    insights_diagnostic_settings   = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")
  })
  default     = {}
  description = "API versions for dependency resource groups (resources_resource_groups), key deployments (resources_deployments), vaults (keyvault_vaults), template-managed keys (keyvault_vaults_keys), workspaces (operationalinsights_workspaces), and diagnostics (insights_diagnostic_settings). Diagnostics has no stable API version."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Dependency retry settings: error_message_regex, interval_seconds, and max_interval_seconds."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags for the example's dependency resources."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Dependency create, read, update, and delete timeouts as Go duration strings."
}
