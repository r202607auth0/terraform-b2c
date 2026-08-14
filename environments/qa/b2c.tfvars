# Swap apim_base_url to the real APIM the day it is available; nothing else changes.

env          = "qa"
auth0_domain = "obp-qa.ca.auth0.com"

# --- Private APIM identity facade -------------------------------------------
apim_base_url             = "https://apim-qa.example.ca/identity/v1"
email_collection_form_url = "https://apim-qa.example.ca/forms/collect-email"

# apim_api_key and action_signing_secret are NOT set here.
# Supply them as TF_VAR_apim_api_key / TF_VAR_action_signing_secret.

# --- Application URLs --------------------------------------------------------
olb_web_base_url    = "https://olb-qa.example.ca"
olb_web_callbacks   = ["https://olb-qa.example.ca/auth/callback", "https://olb-qa.example.ca/signin-oidc"]
olb_web_logout_urls = ["https://olb-qa.example.ca/", "https://olb-qa.example.ca/signed-out"]

olb_mobile_callbacks = [
  "ca.example.olb://obp-qa.ca.auth0.com/ios/ca.example.olb/callback",
  "ca.example.olb://obp-qa.ca.auth0.com/android/ca.example.olb/callback"
]

support_portal_callbacks = ["https://support-qa.example.ca/auth/callback"]

# --- Behaviour ---------------------------------------------------------------
always_on_mfa            = false
legacy_migration_enabled = true
import_mode              = true

blocked_country_codes = ["KP", "IR", "RU", "MM", "SY", "CU"]
blocked_subdivisions  = ["UA-43"]

# --- Test harness ------------------------------------------------------------
enable_test_harness_client = true
