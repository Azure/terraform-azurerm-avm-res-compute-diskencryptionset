# WAF-aligned key rotation example

This scenario evolves the former automatic-key-rotation example. It implements these applicable
recommendations from the [Well-Architected Framework security guidance](https://learn.microsoft.com/azure/well-architected/security/)
and [managed-disk CMK requirements](https://learn.microsoft.com/azure/virtual-machines/disks-enable-customer-managed-keys-portal):

| Concern | Configuration |
| --- | --- |
| Key recovery | Soft delete, purge protection, and 90-day retention on the dependency vault. |
| Key lifecycle | Non-exported RSA-3072 key, wrap/unwrap operations, 180-day expiry, rotation after 90 days, and expiry notification. |
| Encryption continuity | DES automatic rotation, starting from a fully versioned key. |
| Least privilege | System-assigned DES identity receives only Key Vault Crypto Service Encryption User; a separate reader assignment exercises DES-scoped RBAC. |
| Accidental deletion | A `CanNotDelete` lock on the DES. Terraform removes it before teardown. |
| Network access | Key Vault disables public network access and bypasses only trusted Azure services. Key provisioning uses ARM. |
| Auditability | Key Vault audit logs and metrics are sent to a dedicated Log Analytics workspace. |

Dependency resources and location/telemetry controls are separate from module feature inputs.
No private endpoint or application workload is deployed. Workloads requiring private client
access must provide their own private endpoint and DNS configuration. This scenario is not
a claim of complete WAF compliance for arbitrary workloads.

The key is provisioned through a resource-group ARM deployment because the key ARM API
does not support DELETE. Cleanup removes the deployment record and its owning vault;
it does not attempt an unsupported individual key deletion.

```powershell
$env:TF_VAR_location = "westeurope"
avm test e2e --example waf-aligned
```

Use the authorized subscription through Azure authentication. The runner deploys, checks
idempotency, and destroys the example. In addition to resource provisioning and RBAC permissions,
the caller needs subscription-scope deployment permissions when telemetry is enabled.
Log Analytics can incur charges. Purge-protected vaults and keys remain soft-deleted for
90 days after cleanup; unique names avoid collisions on subsequent runs.
