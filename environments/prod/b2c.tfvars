# Test harness is force-disabled in code regardless of this file.

env          = "prod"
auth0_domain = "obp.ca.auth0.com"

# --- Private APIM identity facade -------------------------------------------
apim_base_url             = "https://apim.example.ca/identity/v1"
email_collection_form_url = "https://apim.example.ca/forms/collect-email"

# apim_api_key and action_signing_secret are NOT set here.
# Supply them as TF_VAR_apim_api_key / TF_VAR_action_signing_secret.

# --- Application URLs --------------------------------------------------------
olb_web_base_url    = "https://online.example.ca"
olb_web_callbacks   = ["https://online.example.ca/auth/callback", "https://online.example.ca/signin-oidc"]
olb_web_logout_urls = ["https://online.example.ca/", "https://online.example.ca/signed-out"]

olb_mobile_callbacks = [
  "ca.example.olb://obp.ca.auth0.com/ios/ca.example.olb/callback",
  "ca.example.olb://obp.ca.auth0.com/android/ca.example.olb/callback"
]

support_portal_callbacks = ["https://support.example.ca/auth/callback"]

# --- Behaviour ---------------------------------------------------------------
always_on_mfa            = true
legacy_migration_enabled = true
import_mode              = true

blocked_country_codes = ["KP", "IR", "RU", "MM", "SY", "CU"]
blocked_subdivisions  = ["UA-43"]

# --- Test harness ------------------------------------------------------------
enable_test_harness_client = false
