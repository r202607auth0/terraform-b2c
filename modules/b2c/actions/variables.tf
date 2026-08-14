variable "env" {
  type = string
}

variable "runtime" {
  description = "Auth0 Actions runtime. node18 uses the platform global fetch(), so no npm dependencies are required."
  type        = string
  default     = "node18"
}

variable "b2c_connection_name" {
  description = "Name of the B2C custom database connection. Every Action guards on this so that B2B logins are untouched in the shared tenant."
  type        = string
}

variable "apim_base_url" {
  type = string
}

variable "apim_api_key" {
  type      = string
  sensitive = true
}

variable "action_signing_secret" {
  description = "HMAC secret used to sign the redirect session token for the legacy email-collection form (UC-03)."
  type        = string
  sensitive   = true
}

variable "email_collection_form_url" {
  description = "Hosted form the user is redirected to when a legacy account has no email on file (UC-03). Point at the mock until VeriChannel ships it."
  type        = string
}

variable "blocked_country_codes" {
  description = "ISO-3166-1 alpha-2 codes denied at login (UC-02 Req-3/Req-4)."
  type        = list(string)
  default     = ["KP", "IR", "RU", "MM", "SY", "CU"]
}

variable "blocked_subdivisions" {
  description = "ISO-3166-2 subdivision codes denied at login, e.g. Crimea."
  type        = list(string)
  default     = ["UA-43"]
}

variable "always_on_mfa" {
  description = "true = challenge MFA on every login. false = risk-based only (UC-02 Req-4 option B)."
  type        = bool
  default     = false
}

variable "custom_claim_namespace" {
  type    = string
  default = "https://obp.ca/claims"
}

variable "scripts_path" {
  type    = string
  default = ""
}
