locals {
  scripts_dir = var.scripts_path != "" ? var.scripts_path : "${path.module}/scripts"
}

resource "auth0_connection" "dna" {
  name         = var.connection_name
  display_name = var.display_name
  strategy     = "auth0"

  options {
    enabled_database_customization = true
    import_mode                    = var.import_mode
    disable_signup                 = var.disable_signup
    requires_username              = var.requires_username
    brute_force_protection         = true
    password_policy                = "excellent"

    # UC-07 Req: 12+ chars, upper, lower, digit, special.
    # "excellent" already enforces the four character classes; min_length adds length.
    password_complexity_options {
      min_length = var.password_min_length
    }

    # UC-07 Req: no reuse of previous passwords.
    password_history {
      enable = true
      size   = var.password_history_size
    }

    password_no_personal_info {
      enable = true
    }

    password_dictionary {
      enable = true
    }

    custom_scripts = {
      login           = file("${local.scripts_dir}/login.js")
      get_user        = file("${local.scripts_dir}/get_user.js")
      create          = file("${local.scripts_dir}/create.js")
      verify          = file("${local.scripts_dir}/verify.js")
      change_password = file("${local.scripts_dir}/change_password.js")
      delete          = file("${local.scripts_dir}/delete.js")
    }

    # Exposed to every script as the global `configuration` object.
    configuration = {
      APIM_BASE_URL            = var.apim_base_url
      APIM_API_KEY             = var.apim_api_key
      LEGACY_MIGRATION_ENABLED = tostring(var.legacy_migration_enabled)
    }
  }
}

resource "auth0_connection_clients" "dna" {
  connection_id   = auth0_connection.dna.id
  enabled_clients = var.enabled_clients
}
