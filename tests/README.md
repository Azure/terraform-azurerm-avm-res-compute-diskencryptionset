# Tests

Run `avm test unit` for the provider-mocked defaults, locks, key rotation, identity, and input-validation checks. These tests do not contact Azure.

The mocked suite also covers DES-scoped RBAC, automatic Key Vault access, cross-subscription keys,
Managed HSM request construction, and AzAPI version/retry/timeout controls. Managed HSM and
user-assigned-only encryption are not covered by the real-Azure examples.

Set `ARM_SUBSCRIPTION_ID` to an explicitly authorized test subscription and `TF_VAR_location`
to a supported region before running `avm test integration` or `avm test e2e`.
Integration tests exercise the defaults example and clean up their state; E2E tests additionally
require an idempotency plan with no application-resource changes.

Run both `avm test e2e --example defaults` and `avm test e2e --example waf-aligned`.
These commands create real Azure resources and may incur costs. Purge-protected vaults remain
soft-deleted for their retention period after ordinary cleanup; do not weaken that protection
to make tests purge them.

For an upgrade-path check, deploy the previous published AzureRM module, retain its state,
switch to the local module with the input translations documented in the root README, and
require no unintended deletes or replacements before applying. Verify the same DES, lock,
and Key Vault assignment IDs afterwards. Unit tests alone cannot establish state compatibility.
