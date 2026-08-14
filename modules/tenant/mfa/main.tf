# SMS OTP is deliberately absent: it was struck from the UC-05 factor table.
resource "auth0_guardian" "this" {
  policy = var.policy

  email         = var.enable_email_otp
  otp           = var.enable_totp
  recovery_code = var.enable_recovery_code

  webauthn_platform {
    enabled = var.enable_webauthn_platform
  }

  push {
    enabled  = var.enable_push
    provider = var.push_provider

    custom_app {
      app_name = var.guardian_app_name
    }
  }
}
