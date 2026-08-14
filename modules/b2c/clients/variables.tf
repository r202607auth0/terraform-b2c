variable "env" {
  type = string
}

variable "clients" {
  description = "Interactive and machine-to-machine applications for the B2C estate."
  type = map(object({
    name                   = string
    description            = optional(string, "")
    app_type               = string # regular_web | spa | native | non_interactive
    callbacks              = optional(list(string), [])
    allowed_logout_urls    = optional(list(string), [])
    allowed_origins        = optional(list(string), [])
    web_origins            = optional(list(string), [])
    grant_types            = list(string)
    token_endpoint_auth    = optional(string, "client_secret_post") # none for SPA/native
    oidc_conformant        = optional(bool, true)
    sso                    = optional(bool, true)
    cross_origin_auth      = optional(bool, false)
    idle_session_lifetime  = optional(number, 30) # minutes -> refresh token idle
    refresh_token_rotation = optional(bool, true)
    client_metadata        = optional(map(string), {})
  }))
}

variable "m2m_grants" {
  description = <<-EOT
    Client-grant matrix for non_interactive clients.
    Key is "<client_key>:<audience>"; value carries the audience and the scopes.
  EOT
  type = map(object({
    client_key = string
    audience   = string
    scopes     = list(string)
  }))
  default = {}
}
