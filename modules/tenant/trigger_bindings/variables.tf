variable "post_login_actions" {
  description = <<-EOT
    Ordered list of {id, display_name} for the post-login trigger. Order is the
    execution order. B2B entries come first by convention so that an existing
    partner rule cannot be short-circuited by a B2C rule.
  EOT
  type = list(object({
    id           = string
    display_name = string
  }))
  default = []
}

variable "pre_user_registration_actions" {
  type = list(object({
    id           = string
    display_name = string
  }))
  default = []
}

variable "password_reset_post_challenge_actions" {
  type = list(object({
    id           = string
    display_name = string
  }))
  default = []
}

variable "post_change_password_actions" {
  type = list(object({
    id           = string
    display_name = string
  }))
  default = []
}
