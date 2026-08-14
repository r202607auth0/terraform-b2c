output "identifiers" {
  description = "Map of logical API key => resource server identifier (audience)."
  value       = { for k, v in auth0_resource_server.this : k => v.identifier }
}

output "ids" {
  description = "Map of logical API key => Auth0 resource server id."
  value       = { for k, v in auth0_resource_server.this : k => v.id }
}

output "scopes" {
  description = "Map of logical API key => list of scope names."
  value       = { for k, v in var.apis : k => keys(v.scopes) }
}
