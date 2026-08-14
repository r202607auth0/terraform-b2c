output "connection_name" {
  description = "Use as the `realm` parameter in password-realm grant calls."
  value       = module.connection_dna.connection_name
}

output "client_ids" {
  value = module.clients.ids
}

output "api_identifiers" {
  value = module.apis.identifiers
}

output "role_ids" {
  value = module.rbac.role_ids
}

# Consumed by stacks/tenant to build the trigger bindings.
output "post_login_actions" {
  value = [
    for i, id in module.actions.post_login_action_ids : {
      id           = id
      display_name = module.actions.post_login_action_names[i]
    }
  ]
}

output "pre_user_registration_actions" {
  value = [{
    id           = module.actions.pre_user_registration_action_id
    display_name = module.actions.pre_user_registration_action_name
  }]
}

output "password_reset_post_challenge_actions" {
  value = [{
    id           = module.actions.password_reset_post_challenge_action_id
    display_name = module.actions.password_reset_post_challenge_action_name
  }]
}

output "post_change_password_actions" {
  value = [{
    id           = module.actions.post_change_password_action_id
    display_name = module.actions.post_change_password_action_name
  }]
}
