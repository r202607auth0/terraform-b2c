resource "auth0_attack_protection" "this" {
  brute_force_protection {
    enabled      = true
    max_attempts = var.brute_force_max_attempts
    mode         = "count_per_identifier_and_ip"
    shields      = var.brute_force_shields
    allowlist    = var.brute_force_allowlist
  }

  suspicious_ip_throttling {
    enabled   = true
    shields   = ["block", "admin_notification"]
    allowlist = var.brute_force_allowlist

    pre_login {
      max_attempts = var.suspicious_ip_max_attempts_pre_login
      rate         = 864000
    }

    pre_user_registration {
      max_attempts = var.suspicious_ip_max_attempts_pre_registration
      rate         = 1200
    }
  }

  breached_password_detection {
    enabled = true
    method  = var.breached_password_method
    shields = ["block", "admin_notification"]

    pre_user_registration {
      shields = ["block"]
    }

    pre_change_password {
      shields = ["block"]
    }
  }
}
