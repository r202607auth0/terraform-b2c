# NOTE: this module deliberately does NOT create auth0_trigger_actions.
# The tenant is shared with B2B, and a trigger binding is a tenant singleton:
# two stacks binding the same trigger will fight on every apply. Bindings are
# owned by stacks/tenant/ which composes the B2B and B2C ordered lists.

output "post_login_action_ids" {
  description = "Ordered list of B2C post-login Action ids, to be consumed by stacks/tenant."
  value = [
    auth0_action.access_control.id,
    auth0_action.legacy_email_collection.id,
    auth0_action.adaptive_mfa.id,
    auth0_action.custom_claims.id,
  ]
}

output "post_login_action_names" {
  value = [
    auth0_action.access_control.name,
    auth0_action.legacy_email_collection.name,
    auth0_action.adaptive_mfa.name,
    auth0_action.custom_claims.name,
  ]
}

output "pre_user_registration_action_id" {
  value = auth0_action.pre_user_registration.id
}

output "pre_user_registration_action_name" {
  value = auth0_action.pre_user_registration.name
}

output "password_reset_post_challenge_action_id" {
  value = auth0_action.password_reset_post_challenge.id
}

output "password_reset_post_challenge_action_name" {
  value = auth0_action.password_reset_post_challenge.name
}

output "post_change_password_action_id" {
  value = auth0_action.post_change_password.id
}

output "post_change_password_action_name" {
  value = auth0_action.post_change_password.name
}
