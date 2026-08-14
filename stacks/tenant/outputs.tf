output "post_login_binding_order" {
  description = "Effective execution order of the post-login trigger, B2B first."
  value       = [for a in local.post_login_actions : a.display_name]
}
