variable "env" {
  description = "Environment short name (dev | qa | staging | prod)."
  type        = string
}

variable "apis" {
  description = <<-EOT
    Map of resource servers (APIs) to create. Key is the logical name used for
    Terraform addressing; it must be stable for the life of the resource.
  EOT
  type = map(object({
    name                                            = string
    identifier                                      = string
    signing_alg                                     = optional(string, "RS256")
    token_lifetime                                  = optional(number, 900)
    token_lifetime_for_web                          = optional(number, 900)
    allow_offline_access                            = optional(bool, false)
    skip_consent_for_verifiable_first_party_clients = optional(bool, true)
    enforce_policies                                = optional(bool, true)
    token_dialect                                   = optional(string, "access_token_authz")
    scopes                                          = map(string)
  }))
}
