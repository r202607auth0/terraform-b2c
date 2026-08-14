variable "connection_name" {
  description = "Name of the custom database connection backing OLB retail customers."
  type        = string
  default     = "OLB-B2C-DNA"
}

variable "display_name" {
  type    = string
  default = "Online Banking"
}

variable "import_mode" {
  description = <<-EOT
    true  = trickle migration. Auth0 calls the Login script for users it does not
            yet hold, then imports the profile and the password hash on success.
    false = Auth0 is the sole credential store; the legacy Login script is never
            called. Flip this only after the legacy population has drained.
  EOT
  type        = bool
  default     = true
}

variable "disable_signup" {
  description = "Blocks direct signup on the connection. Registration (UC-01) is still possible because the pre-user-registration Action drives it."
  type        = bool
  default     = false
}

variable "requires_username" {
  description = "Legacy identifiers are usernames, not emails. Keep true while legacy users exist (UC-03)."
  type        = bool
  default     = true
}

variable "apim_base_url" {
  description = "Base URL of the Private APIM identity facade, e.g. https://apim-dev.example.com/identity/v1. Point at the mock until APIM is live."
  type        = string
}

variable "apim_api_key" {
  description = "Subscription key / shared secret for the APIM identity facade."
  type        = string
  sensitive   = true
}

variable "legacy_migration_enabled" {
  description = "Master switch for the legacy lookup path inside the scripts."
  type        = bool
  default     = true
}

variable "enabled_clients" {
  description = "Client IDs permitted to use this connection."
  type        = list(string)
  default     = []
}

variable "password_min_length" {
  type    = number
  default = 12
}

variable "password_history_size" {
  type    = number
  default = 24
}

variable "scripts_path" {
  description = "Directory containing the six custom database scripts."
  type        = string
  default     = ""
}
