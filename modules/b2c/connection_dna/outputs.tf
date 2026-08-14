output "connection_id" {
  value = auth0_connection.dna.id
}

output "connection_name" {
  description = "Use this as the `realm` in password-realm grant calls from Postman."
  value       = auth0_connection.dna.name
}
