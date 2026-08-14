output "ids" {
  description = "Map of logical client key => Auth0 client_id."
  value       = { for k, v in auth0_client.this : k => v.id }
}

output "client_ids_by_name" {
  value = { for k, v in auth0_client.this : v.name => v.id }
}
