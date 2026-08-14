data "terraform_remote_state" "b2c" {
  backend = "s3"

  config = {
    bucket = var.b2c_state_bucket
    key    = var.b2c_state_key
    region = var.state_region
  }
}

data "terraform_remote_state" "b2b" {
  count   = var.b2b_state_key != "" ? 1 : 0
  backend = "s3"

  config = {
    bucket = var.b2c_state_bucket
    key    = var.b2b_state_key
    region = var.state_region
  }
}

locals {
  b2b_post_login = length(data.terraform_remote_state.b2b) > 0 ? try(
    data.terraform_remote_state.b2b[0].outputs.post_login_actions,
    var.b2b_post_login_actions
  ) : var.b2b_post_login_actions

  # B2B first: an existing partner control must not be short-circuited by a
  # B2C rule that returns early on a connection mismatch.
  post_login_actions = concat(
    local.b2b_post_login,
    data.terraform_remote_state.b2c.outputs.post_login_actions
  )
}

module "attack_protection" {
  source = "../../modules/tenant/attack_protection"

  brute_force_max_attempts = var.brute_force_max_attempts
  brute_force_allowlist    = var.brute_force_allowlist
  brute_force_shields      = ["block", "user_notification"]
}

module "mfa" {
  source = "../../modules/tenant/mfa"

  policy               = var.mfa_policy
  enable_email_otp     = true
  enable_totp          = true
  enable_recovery_code = true
  enable_push          = var.enable_push_mfa
}

module "experience" {
  source = "../../modules/tenant/experience"

  enabled_locales       = ["en", "fr-CA"]
  logo_url              = var.logo_url
  support_email         = var.support_email
  support_url           = var.support_url
  from_email            = var.from_email
  manage_email_provider = var.manage_email_provider
  ses_access_key_id     = var.ses_access_key_id
  ses_secret_access_key = var.ses_secret_access_key
  ses_region            = var.ses_region

  # UC-07 acceptance criterion.
  reset_password_url_lifetime = 900
}

module "trigger_bindings" {
  source = "../../modules/tenant/trigger_bindings"

  post_login_actions                    = local.post_login_actions
  pre_user_registration_actions         = data.terraform_remote_state.b2c.outputs.pre_user_registration_actions
  password_reset_post_challenge_actions = data.terraform_remote_state.b2c.outputs.password_reset_post_challenge_actions
  post_change_password_actions          = data.terraform_remote_state.b2c.outputs.post_change_password_actions
}
