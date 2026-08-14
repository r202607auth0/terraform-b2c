variable "env" {
  type = string
}

variable "auth0_domain" {
  type = string
}

# ---------------------------------------------------------------- remote state
variable "b2c_state_bucket" {
  type = string
}

variable "b2c_state_key" {
  type = string
}

variable "state_region" {
  type    = string
  default = "ca-central-1"
}

variable "b2b_state_key" {
  description = <<-EOT
    Key of the existing B2B stack's state. Leave empty until the B2B stack
    exports the four *_actions outputs; the bindings will then contain B2C
    Actions only, and B2B Actions must be listed in b2b_post_login_actions.
  EOT
  type    = string
  default = ""
}

variable "b2b_post_login_actions" {
  description = "Manual fallback: B2B post-login Actions, in execution order. Get ids with `auth0 actions list --json`."
  type = list(object({
    id           = string
    display_name = string
  }))
  default = []
}

# ---------------------------------------------------------------- MFA
variable "mfa_policy" {
  description = "Leave empty so the post-login Action decides. See modules/tenant/mfa."
  type        = string
  default     = ""
}

variable "enable_push_mfa" {
  type    = bool
  default = false
}

# ---------------------------------------------------------------- lockout
variable "brute_force_max_attempts" {
  type    = number
  default = 3
}

variable "brute_force_allowlist" {
  description = "CI runner egress IPs."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------- experience
variable "support_email" {
  type = string
}

variable "support_url" {
  type = string
}

variable "from_email" {
  type = string
}

variable "logo_url" {
  type    = string
  default = ""
}

variable "manage_email_provider" {
  type    = bool
  default = false
}

variable "ses_access_key_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ses_secret_access_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ses_region" {
  type    = string
  default = "ca-central-1"
}
