variable "roles" {
  description = "Roles and the API scopes each one carries."
  type = map(object({
    name        = string
    description = string
    permissions = map(list(string)) # audience => [scope, ...]
  }))
}
