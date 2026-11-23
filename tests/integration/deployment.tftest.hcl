run "defaults" {
  command = apply

  module {
    source = "./examples/defaults"
  }

  assert {
    condition     = output.system_assigned_mi_principal_id != null && startswith(output.key_vault_key_url, "https://")
    error_message = "The deployed DES must expose its encryption identity and versioned key URL."
  }
}

run "defaults_idempotency" {
  command = plan

  module {
    source = "./examples/defaults"
  }

  assert {
    condition     = output.resource_id == run.defaults.resource_id && output.key_vault_key_url == run.defaults.key_vault_key_url
    error_message = "A subsequent plan must retain the deployed DES and key."
  }
}
