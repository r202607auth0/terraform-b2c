variable "policy" {
  description = <<-EOT
    all-applications = challenge on every login (UC-02 Req-4 "always on")
    confidence-score = Auth0 adaptive MFA, challenge on medium/low confidence
    ""               = never challenge at the tenant level; the post-login Action
                       decides. This is the recommended value because UC-04
                       step-up and UC-02 risk rules live in code.
  EOT
  type        = string
  default     = ""
}

variable "enable_email_otp" {
  description = "UC-05 factor: Email OTP, out-of-band, AAL2, low strength."
  type        = bool
  default     = true
}

variable "enable_totp" {
  description = "UC-05 factor: TOTP authenticator app, AAL2, medium strength."
  type        = bool
  default     = true
}

variable "enable_recovery_code" {
  type    = bool
  default = true
}

variable "enable_push" {
  description = "UC-05 factor: Guardian push. Phase-2 rollout - leave false until the mobile SDK is embedded in VeriChannel."
  type        = bool
  default     = false
}

variable "push_provider" {
  type    = string
  default = "guardian"
}

variable "guardian_app_name" {
  type    = string
  default = "Online Banking"
}

variable "enable_webauthn_platform" {
  type    = bool
  default = false
}
