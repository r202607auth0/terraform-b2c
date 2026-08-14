output "role_ids" {
  value = { for k, v in auth0_role.this : k => v.id }
}
