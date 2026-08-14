variable "env" {
  description = "dev | qa | staging | prod"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "staging", "prod"], var.env)
    error_message = "env must be one of dev, qa, staging, prod."
  }
}

variable "auth0_domain" {
  description = "Tenant domain, e.g. obp-dev.ca.auth0.com. Used to build the Management API audience."
  type        = string
}

# ---------------------------------------------------------------- integration
variable "apim_base_url" {
  description = "Private APIM identity facade base URL. Point at the mock tunnel until APIM is live."
  type        = string
}

variable "apim_api_key" {
  description = "Supplied via TF_VAR_apim_api_key from the CI secret store."
  type        = string
  sensitive   = true
}

variable "action_signing_secret" {
  description = "Supplied via TF_VAR_action_signing_secret."
  type        = string
  sensitive   = true
}

variable "email_collection_form_url" {
  description = "UC-03 hosted form. Mock form until VeriChannel ships the screen."
  type        = string
}

variable "legacy_migration_enabled" {
  type    = bool
  default = true
}

variable "import_mode" {
  type    = bool
  default = true
}

# ---------------------------------------------------------------- application URLs
variable "olb_web_base_url" {
  description = "VeriChannel web origin, e.g. https://olb-dev.example.ca"
  type        = string
}

variable "olb_web_callbacks" {
  type = list(string)
}

variable "olb_web_logout_urls" {
  type = list(string)
}

variable "olb_mobile_callbacks" {
  description = "Custom scheme and universal-link callbacks for the VeriChannel mobile app."
  type        = list(string)
  default     = []
}

variable "support_portal_callbacks" {
  type    = list(string)
  default = []
}

# ---------------------------------------------------------------- behaviour
variable "always_on_mfa" {
  type    = bool
  default = false
}

variable "blocked_country_codes" {
  type    = list(string)
  default = ["KP", "IR", "RU", "MM", "SY", "CU"]
}

variable "blocked_subdivisions" {
  type    = list(string)
  default = ["UA-43"]
}

variable "actions_runtime" {
  type    = string
  default = "node18"
}

variable "custom_claim_namespace" {
  type    = string
  default = "https://obp.ca/claims"
}

variable "api_audience_prefix" {
  description = "Audience namespace for the OLB resource servers."
  type        = string
  default     = "https://api.obp.ca"
}

# ---------------------------------------------------------------- test harness
variable "enable_test_harness_client" {
  description = <<-EOT
    Creates a confidential client with the password-realm and MFA grants so the
    whole estate can be driven from Postman with no browser and no front end.
    MUST be false in prod - the resource-owner password grant is not acceptable
    for a production banking channel.
  EOT
  type    = bool
  default = false
}
