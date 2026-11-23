---
description: Current published AVM requirements that supersede older governance-managed guidance.
applyTo: "**/*.tf,**/*.hcl,**/*.md"
---

# Published specification corrections

Read the current sources linked from <https://azure.github.io/Azure-Verified-Modules/llms.txt>.
Published specifications take precedence over older managed skills and instructions:

- [TFNFR25](https://azure.github.io/Azure-Verified-Modules/spec/TFNFR25) and
  [TFFR8](https://azure.github.io/Azure-Verified-Modules/spec/TFFR8) require Terraform
  1.11.0 or later for every AVM Terraform module, even with empty `ignore_body_changes`.
- [SFR3](https://azure.github.io/Azure-Verified-Modules/spec/SFR3) uses metadata-backed
  empty AzAPI subscription deployments. Do not reintroduce `modtm` or per-resource
  telemetry headers. Pass `enable_telemetry` through to utility modules.
- [TFNFR42](https://azure.github.io/Azure-Verified-Modules/spec/TFNFR42) is published.
  Resource modules require executable `examples/defaults` and `examples/waf-aligned`
  scenarios; their directory names alone do not prove semantic compliance.

Governance sync owns the supplied instruction and skill files. Keep local corrections
in this supplemental instruction rather than repeatedly editing files that sync replaces.
