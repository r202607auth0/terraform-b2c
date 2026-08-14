locals {
  scripts_dir = var.scripts_path != "" ? var.scripts_path : "${path.module}/scripts"

  common_secrets = {
    APIM_BASE_URL          = var.apim_base_url
    APIM_API_KEY           = var.apim_api_key
    B2C_CONNECTION_NAME    = var.b2c_connection_name
    CUSTOM_CLAIM_NAMESPACE = var.custom_claim_namespace
    ENVIRONMENT            = var.env
  }
}

# ---------------------------------------------------------------------------
# UC-01 : CIF validation before the user record is created.
# ---------------------------------------------------------------------------
resource "auth0_action" "pre_user_registration" {
  name    = "b2c-pre-user-registration-cif-validation"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/pre-user-registration/cif-validation.js")

  supported_triggers {
    id      = "pre-user-registration"
    version = "v2"
  }

  dynamic "secrets" {
    for_each = local.common_secrets
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}

# ---------------------------------------------------------------------------
# UC-02 : deny list, geo block, email verification enforcement.
# Runs first in the post-login chain so that a denied login costs nothing else.
# ---------------------------------------------------------------------------
resource "auth0_action" "access_control" {
  name    = "b2c-post-login-01-access-control"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/post-login/01-access-control.js")

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  dynamic "secrets" {
    for_each = merge(local.common_secrets, {
      BLOCKED_COUNTRIES    = join(",", var.blocked_country_codes)
      BLOCKED_SUBDIVISIONS = join(",", var.blocked_subdivisions)
    })
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}

# ---------------------------------------------------------------------------
# UC-03 : legacy user has no email on file -> redirect to collection form.
# ---------------------------------------------------------------------------
resource "auth0_action" "legacy_email_collection" {
  name    = "b2c-post-login-02-legacy-email-collection"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/post-login/02-legacy-email-collection.js")

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  dynamic "secrets" {
    for_each = merge(local.common_secrets, {
      ACTION_SIGNING_SECRET = var.action_signing_secret
      FORM_URL              = var.email_collection_form_url
    })
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}

# ---------------------------------------------------------------------------
# UC-02 / UC-04 / UC-05 : adaptive MFA and step-up enforcement.
# ---------------------------------------------------------------------------
resource "auth0_action" "adaptive_mfa" {
  name    = "b2c-post-login-03-adaptive-mfa"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/post-login/03-adaptive-mfa.js")

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  dynamic "secrets" {
    for_each = merge(local.common_secrets, {
      ALWAYS_ON_MFA = tostring(var.always_on_mfa)
    })
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}

# ---------------------------------------------------------------------------
# Custom claims consumed by VeriChannel / VeriLink and the Private APIM.
# Must run last so downstream Actions can still mutate metadata.
# ---------------------------------------------------------------------------
resource "auth0_action" "custom_claims" {
  name    = "b2c-post-login-04-custom-claims"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/post-login/04-custom-claims.js")

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  dynamic "secrets" {
    for_each = local.common_secrets
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}

# ---------------------------------------------------------------------------
# UC-06 / UC-07 : password reset lifts the lockout, and the customer is told.
# ---------------------------------------------------------------------------
resource "auth0_action" "password_reset_post_challenge" {
  name    = "b2c-password-reset-post-challenge-unlock"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/password-reset-post-challenge/unlock-and-notify.js")

  supported_triggers {
    id      = "password-reset-post-challenge"
    version = "v1"
  }

  dynamic "secrets" {
    for_each = local.common_secrets
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}

# ---------------------------------------------------------------------------
# UC-11 : notify on credential change.
# ---------------------------------------------------------------------------
resource "auth0_action" "post_change_password" {
  name    = "b2c-post-change-password-notify"
  runtime = var.runtime
  deploy  = true
  code    = file("${local.scripts_dir}/post-change-password/notify.js")

  supported_triggers {
    id      = "post-change-password"
    version = "v1"
  }

  dynamic "secrets" {
    for_each = local.common_secrets
    content {
      name  = secrets.key
      value = secrets.value
    }
  }
}
