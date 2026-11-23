# Disk Encryption Set

Azure Verified Resource Module for `Microsoft.Compute/diskEncryptionSets`, implemented with AzAPI.
It manages one disk encryption set and optional resource locks, DES-scoped RBAC assignments,
and Key Vault access for its system-assigned encryption identity. The resource group, encryption
key, and any user-assigned identities belong to the consumer.

## Requirements and key access

- Terraform 1.11 or later, below 2.0, and AzAPI 2.12 or later, below 3.0.
- Supply `name`, `location`, and the existing resource group's ARM ID as `parent_id`.
- Configure `managed_identities` and exactly one of `customer_managed_key` or `managed_hsm_key_id`.
- Key Vault keys must be RSA keys with a fully specified initial version, including when
  `auto_key_rotation_enabled = true`. Enable soft delete and purge protection on the vault.
- By default, the module grants the system-assigned encryption identity **Key Vault Crypto Service
  Encryption User** on the supplied vault. The deployment identity must be able to create that
  assignment. DES-scoped permissions are configured separately through `role_assignments`.
- For user-assigned encryption, configure the same identity in
  `customer_managed_key.user_assigned_identity` and `managed_identities.user_assigned_resource_ids`.
  Disable automatic vault RBAC and grant key access externally before using the DES.
- Managed HSM uses a fully versioned data-plane key URL and externally managed HSM permissions.
  Set `key_vault_role_assignment_enabled = false`. Managed HSM provisioning is not included.
- For cross-subscription vaults, the module omits `activeKey.sourceVault`, as required by Compute.
  Cross-tenant scenarios additionally need the appropriate federated application and externally
  arranged permissions. Consult the service's regional and identity restrictions.

The vault URI is read from the vault's ARM response rather than constructed from a public-cloud
DNS suffix. No data source reads the encryption key or resolves an encryption identity.

With automatic rotation enabled, the configured initial key URL is sent through AzAPI's
write-only body and tracked by a configuration fingerprint. Azure can advance the active
version without Terraform reverting it; explicitly changing the configured key still triggers
an update. The output reports Azure's actual active key URL.

## Examples

- [Defaults](examples/defaults): required and conditional module inputs, with other features
  using module defaults. Dependency setup is separate from DES configuration.
- [WAF-aligned](examples/waf-aligned): automatic key rotation, a deletion lock, DES-scoped RBAC,
  Key Vault rotation and recovery protections, network ACLs, and audit logs.

Both roots require an explicit `location`, expose `enable_telemetry`, use unique names, and
create their own dependency resources. They can be used as real-Azure deployment tests.
Purge-protected vaults remain soft-deleted after cleanup and cannot be purged until retention expires.
The WAF example documents its recommendations and limitations; its name is not a blanket
certification of every workload's WAF requirements.

## AzAPI controls

`resource_types` selects the tested API versions. `retry` and `timeouts` apply to every managed
resource. `ignore_body_changes` accepts body-relative dot paths for each resource type; changes
take effect only after apply. Configuration on an ignored path is not sent to Azure until the
path is removed. Do not target individual list indices.

The DES supports tags, managed identities, resource locks, and RBAC. It does not expose a
private-link endpoint or diagnostic-settings interface; the WAF example monitors its Key Vault
dependency instead. `system_assigned_mi_principal_id` is null for user-assigned-only deployments.

## Upgrade from the AzureRM implementation

This is a breaking interface update and must be released as a new **0.x minor version**.
The legacy repository and Registry names do not change as part of this migration.

1. Back up state using `terraform state pull` and record the current resource IDs.
2. Upgrade to Terraform 1.11 or later.
3. Replace `resource_group_name` with `parent_id`, the complete resource-group ARM ID.
4. Replace `key_vault_key_id` and `key_vault_resource_id` with `customer_managed_key`:

   ```hcl
   customer_managed_key = {
     key_vault_resource_id = "/subscriptions/<subscription>/resourceGroups/<group>/providers/Microsoft.KeyVault/vaults/<vault>"
     key_name              = "<existing-key-name>"
     key_version           = "<existing-key-version>"
   }
   ```

   Keep the same vault, key, initial version, resource name, location, encryption type,
   identity configuration, lock name, and RBAC toggle. A versionless URI is no longer accepted
   as an initial key, because the Compute ARM API requires a version even with rotation enabled.
   The `managed_hsm_key_id` alternative remains a fully versioned HTTPS URL.
5. Run `terraform init -upgrade`, followed by `terraform plan`. Retain the old AzureRM provider
   in the calling root for this initialization when it is still referenced by existing state.
   Existing telemetry state may also require the old `modtm` and `random` providers for one
   final initialization; the module forgets their telemetry-only resources without destroying them.
6. Inspect the complete plan before applying. Declarative moves cover the DES, management lock,
   and both historic cardinalities of the Key Vault assignment. The existing assignment's UUID
   is retained. **Do not apply a plan containing unintended deletes or replacements.**
7. Apply the migration, verify all resource IDs are unchanged, and plan again. Remove obsolete
   provider declarations only after their resources are no longer referenced by state.

The generated telemetry deployment intentionally receives an in-place update on normal plans;
it must not be mistaken for DES replacement or application-resource drift.

## Telemetry and validation

Telemetry is on by default and can be disabled with `enable_telemetry = false`. Avm.Authoring
maintains the empty subscription-scoped Azure deployment used for reporting; no `modtm` provider
or per-resource telemetry headers are required for new installations. With telemetry enabled,
the deployment identity needs subscription-scope deployment read, write, and delete permissions.

Use the MAR-distributed Avm.Authoring PowerShell module:

```powershell
avm test unit
avm test integration
avm test e2e --example defaults
avm test e2e --example waf-aligned
avm pre-commit
# Review and commit the complete worktree before the clean-worktree gate.
avm pr-check
```

Real-Azure tests create and delete resources and require appropriate Azure credentials. Supply
`TF_VAR_location` and the authorized `ARM_SUBSCRIPTION_ID`; no subscription is embedded in the examples.
