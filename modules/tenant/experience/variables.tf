variable "enabled_locales" {
  description = <<-EOT
    Declared here for documentation and for any future auth0_tenant resource.
    NOT applied by this module: enabled_locales lives on auth0_tenant, which is a
    tenant singleton the B2B stack may already own (see docs/00-architecture-decisions.md,
    AD-01). Set it once, in whichever stack owns auth0_tenant.
    First entry is the default. English and Canadian French are a hard
    requirement across UC-01..UC-15.
  EOT
  type        = list(string)
  default     = ["en", "fr-CA"]
}

variable "logo_url" {
  type    = string
  default = ""
}

variable "primary_color" {
  type    = string
  default = "#0B5FFF"
}

variable "page_background_color" {
  type    = string
  default = "#F4F6F9"
}

variable "support_email" {
  type = string
}

variable "support_url" {
  type = string
}

variable "from_email" {
  type = string
}

variable "manage_email_provider" {
  description = "Set false if the B2B stack already owns auth0_email_provider for this tenant."
  type        = bool
  default     = false
}

variable "email_provider_name" {
  type    = string
  default = "ses"
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

variable "templates_path" {
  type    = string
  default = ""
}

variable "reset_password_url_lifetime" {
  description = "UC-07 acceptance criterion: the reset link expires in 15 minutes."
  type        = number
  default     = 900
}
