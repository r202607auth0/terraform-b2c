variable "brute_force_max_attempts" {
  description = "UC-06: lock the account after this many consecutive failed password attempts."
  type        = number
  default     = 3
}

variable "brute_force_shields" {
  description = "block = deny the IP/identifier pair. user_notification = email the customer (UC-06 Req-3)."
  type        = list(string)
  default     = ["block", "user_notification"]
}

variable "brute_force_allowlist" {
  description = "Egress IPs of your test runners, so CI does not lock itself out."
  type        = list(string)
  default     = []
}

variable "suspicious_ip_max_attempts_pre_login" {
  type    = number
  default = 100
}

variable "suspicious_ip_max_attempts_pre_registration" {
  type    = number
  default = 50
}

variable "breached_password_method" {
  type    = string
  default = "standard"
}
