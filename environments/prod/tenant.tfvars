env          = "prod"
auth0_domain = "obp.ca.auth0.com"

b2c_state_bucket = "obp-identity-tfstate-prod"
b2c_state_key    = "auth0/prod/b2c.tfstate"
state_region     = "ca-central-1"

# Set once the B2B stack exports post_login_actions; until then list the B2B
# Actions explicitly in b2b_post_login_actions below.
b2b_state_key = ""

b2b_post_login_actions = [
  # { id = "<uuid>", display_name = "b2b-partner-id-claims" },
  # { id = "<uuid>", display_name = "b2b-fastfunds-custom-claims" },
]

# --- MFA ---------------------------------------------------------------------
mfa_policy      = ""
enable_push_mfa = false

# --- Lockout (UC-06) ---------------------------------------------------------
brute_force_max_attempts = 3
brute_force_allowlist    = []

# --- Experience --------------------------------------------------------------
support_email = "support@example.ca"
support_url   = "https://online.example.ca/help"
from_email    = "no-reply@example.ca"
logo_url      = ""

# Set true only if the B2B stack does not already own auth0_email_provider.
manage_email_provider = false
