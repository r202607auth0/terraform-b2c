# Trigger bindings are tenant singletons. Exactly one Terraform stack in the
# whole estate may own them, otherwise every apply flip-flops the binding list.

resource "auth0_trigger_actions" "post_login" {
  count   = length(var.post_login_actions) > 0 ? 1 : 0
  trigger = "post-login"

  dynamic "actions" {
    for_each = var.post_login_actions
    content {
      id           = actions.value.id
      display_name = actions.value.display_name
    }
  }
}

resource "auth0_trigger_actions" "pre_user_registration" {
  count   = length(var.pre_user_registration_actions) > 0 ? 1 : 0
  trigger = "pre-user-registration"

  dynamic "actions" {
    for_each = var.pre_user_registration_actions
    content {
      id           = actions.value.id
      display_name = actions.value.display_name
    }
  }
}

resource "auth0_trigger_actions" "password_reset_post_challenge" {
  count   = length(var.password_reset_post_challenge_actions) > 0 ? 1 : 0
  trigger = "password-reset-post-challenge"

  dynamic "actions" {
    for_each = var.password_reset_post_challenge_actions
    content {
      id           = actions.value.id
      display_name = actions.value.display_name
    }
  }
}

resource "auth0_trigger_actions" "post_change_password" {
  count   = length(var.post_change_password_actions) > 0 ? 1 : 0
  trigger = "post-change-password"

  dynamic "actions" {
    for_each = var.post_change_password_actions
    content {
      id           = actions.value.id
      display_name = actions.value.display_name
    }
  }
}
