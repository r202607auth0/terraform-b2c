locals {
  templates_dir = var.templates_path != "" ? var.templates_path : "${path.module}/templates"
}

resource "auth0_branding" "this" {
  logo_url = var.logo_url != "" ? var.logo_url : null

  colors {
    primary         = var.primary_color
    page_background = var.page_background_color
  }
}

resource "auth0_prompt" "this" {
  universal_login_experience     = "new"
  identifier_first               = true
  webauthn_platform_first_factor = false
}

# Bilingual custom text. Auth0 keeps one resource per prompt per language, so
# every screen the customer can reach must be declared twice.
resource "auth0_prompt_custom_text" "login_en" {
  prompt   = "login"
  language = "en"
  body     = file("${local.templates_dir}/prompt-login-en.json")
}

resource "auth0_prompt_custom_text" "login_fr" {
  prompt   = "login"
  language = "fr-CA"
  body     = file("${local.templates_dir}/prompt-login-fr-CA.json")
}

resource "auth0_prompt_custom_text" "signup_en" {
  prompt   = "signup"
  language = "en"
  body     = file("${local.templates_dir}/prompt-signup-en.json")
}

resource "auth0_prompt_custom_text" "signup_fr" {
  prompt   = "signup"
  language = "fr-CA"
  body     = file("${local.templates_dir}/prompt-signup-fr-CA.json")
}

resource "auth0_email_provider" "this" {
  count = var.manage_email_provider ? 1 : 0

  name                 = var.email_provider_name
  enabled              = true
  default_from_address = var.from_email

  credentials {
    access_key_id     = var.ses_access_key_id
    secret_access_key = var.ses_secret_access_key
    region            = var.ses_region
  }
}

resource "auth0_email_template" "verify_email" {
  template                = "verify_email"
  body                    = file("${local.templates_dir}/verify_email.html")
  from                    = var.from_email
  subject                 = "Verify your Online Banking email address"
  syntax                  = "liquid"
  enabled                 = true
  url_lifetime_in_seconds = 86400
}

resource "auth0_email_template" "reset_email" {
  template                = "reset_email"
  body                    = file("${local.templates_dir}/reset_email.html")
  from                    = var.from_email
  subject                 = "Reset your Online Banking password"
  syntax                  = "liquid"
  enabled                 = true
  url_lifetime_in_seconds = var.reset_password_url_lifetime
}

resource "auth0_email_template" "blocked_account" {
  template = "blocked_account"
  body     = file("${local.templates_dir}/blocked_account.html")
  from     = var.from_email
  subject  = "Your Online Banking account has been locked"
  syntax   = "liquid"
  enabled  = true
}

resource "auth0_email_template" "mfa_oob_code" {
  template = "mfa_oob_code"
  body     = file("${local.templates_dir}/mfa_oob_code.html")
  from     = var.from_email
  subject  = "Your Online Banking verification code"
  syntax   = "liquid"
  enabled  = true
}
