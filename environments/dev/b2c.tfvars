# Points at the mock. Nothing in this environment talks to a real core.

env          = "dev"
auth0_domain = "obp-dev.ca.auth0.com"

# --- Private APIM identity facade -------------------------------------------
apim_base_url             = "https://obp-dna-mock.free.beeceptor.com/identity/v1"
email_collection_form_url = "https://obp-dna-mock.free.beeceptor.com/forms/collect-email"

# apim_api_key and action_signing_secret are NOT set here.
# Supply them as TF_VAR_apim_api_key / TF_VAR_action_signing_secret.

# --- Application URLs --------------------------------------------------------
olb_web_base_url    = "https://olb-dev.example.ca"
olb_web_callbacks   = ["https://olb-dev.example.ca/auth/callback", "https://olb-dev.example.ca/signin-oidc"]
olb_web_logout_urls = ["https://olb-dev.example.ca/", "https://olb-dev.example.ca/signed-out"]

olb_mobile_callbacks = [
  "ca.example.olb://obp-dev.ca.auth0.com/ios/ca.example.olb/callback",
  "ca.example.olb://obp-dev.ca.auth0.com/android/ca.example.olb/callback"
]

support_portal_callbacks = ["https://support-dev.example.ca/auth/callback"]

# --- Behaviour ---------------------------------------------------------------
always_on_mfa            = false
legacy_migration_enabled = true
import_mode              = true

blocked_country_codes = ["KP", "IR", "RU", "MM", "SY", "CU"]
blocked_subdivisions  = ["UA-43"]

# --- Test harness ------------------------------------------------------------
enable_test_harness_client = true
