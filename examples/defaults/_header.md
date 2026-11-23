# Defaults example

Deploys a Disk Encryption Set using required and applicable conditional inputs. Optional
module features use their defaults: rotation is off, no DES lock or DES-scoped RBAC is added,
and automatic system-assigned Key Vault access is enabled.

The resource group, purge-protected Key Vault, and versioned RSA key are test prerequisites,
not optional DES feature overrides. Public network access is disabled; the trusted Azure
services bypass permits disk encryption. Keys are created through a resource-group ARM
deployment because the key ARM API does not support DELETE. Destroy removes the deployment
record and its owning vault; it does not attempt an unsupported individual key deletion.

Supply an authorized subscription through Azure authentication and set `TF_VAR_location`.
Telemetry is explicit and can be disabled using `TF_VAR_enable_telemetry=false`.
The deployment identity needs permission to manage resource groups, vaults, keys, DES resources,
role assignments, and subscription-scope telemetry deployments.

```powershell
$env:TF_VAR_location = "westeurope"
avm test e2e --example defaults
```

The E2E runner deploys, checks idempotency, and destroys the example. Key Vault soft delete
and 90-day purge protection intentionally retain the deleted vault and its keys; their names
cannot be immediately reused. New runs generate new names.
