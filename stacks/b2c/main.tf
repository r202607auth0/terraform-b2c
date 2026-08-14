locals {
  connection_name = "OLB-B2C-DNA"

  mgmt_api_audience = "https://${var.auth0_domain}/api/v2/"

  olb_api      = "${var.api_audience_prefix}/olb"
  support_api  = "${var.api_audience_prefix}/support"

  is_prod = var.env == "prod"

  # Guard rail: the resource-owner password grant must never exist in prod,
  # whatever the tfvars say.
  test_harness_enabled = var.enable_test_harness_client && !local.is_prod
}

# ---------------------------------------------------------------------------
# APIs (resource servers)
# ---------------------------------------------------------------------------
module "apis" {
  source = "../../modules/b2c/apis"

  env = var.env

  apis = {
    olb = {
      name       = "OLB Customer API (${upper(var.env)})"
      identifier = local.olb_api
      scopes = {
        "read:profile"                 = "Read the signed-in customer profile"
        "update:profile"               = "Update contact details and preferences (UC-08)"
        "read:accounts"                = "Read account summary and balances"
        "manage:bill_payees"           = "Add or change bill payees (high-risk, UC-04)"
        "manage:etransfer_recipients"  = "Add or change e-Transfer recipients (high-risk, UC-04)"
        "manage:interac_profile"       = "Create or edit the Interac profile (high-risk, UC-04)"
        "manage:cra_direct_deposit"    = "Register CRA direct deposit (high-risk, UC-04)"
        "manage:delegates"             = "Add or manage delegates (high-risk, UC-10)"
        "read:sessions"                = "List the customer's own active sessions (UC-09)"
        "revoke:sessions"              = "Revoke the customer's own sessions (UC-09)"
        "read:login_history"           = "Read the customer's own login history (UC-09)"
      }
    }

    support = {
      name       = "OLB Support API (${upper(var.env)})"
      identifier = local.support_api
      scopes = {
        "read:customer"            = "Look up a customer record"
        "initiate:password_reset"  = "Trigger a password reset on the customer's behalf (UC-12)"
        "lock:customer"            = "Lock a customer account (UC-14)"
        "unlock:customer"          = "Unlock or unblock a customer account (UC-15)"
        "read:audit"               = "Read the support audit trail"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------
module "clients" {
  source = "../../modules/b2c/clients"

  env = var.env

  clients = merge(
    {
      olb_web = {
        name                = "OLB Web - VeriChannel BFF (${upper(var.env)})"
        description         = "Confidential client used by the VeriChannel backend-for-frontend. The browser never holds a token."
        app_type            = "regular_web"
        callbacks           = var.olb_web_callbacks
        allowed_logout_urls = var.olb_web_logout_urls
        allowed_origins     = [var.olb_web_base_url]
        web_origins         = [var.olb_web_base_url]
        grant_types         = ["authorization_code", "refresh_token"]
        token_endpoint_auth = "client_secret_post"
        client_metadata     = { channel = "web", owner = "verichannel" }
      }

      olb_mobile = {
        name                = "OLB Mobile - VeriChannel (${upper(var.env)})"
        description         = "Public client. PKCE only; a mobile binary cannot hold a client secret."
        app_type            = "native"
        callbacks           = var.olb_mobile_callbacks
        allowed_logout_urls = var.olb_mobile_callbacks
        grant_types         = ["authorization_code", "refresh_token"]
        token_endpoint_auth = "none"
        client_metadata     = { channel = "mobile", owner = "verichannel" }
      }

      support_portal = {
        name                = "OLB Support Portal (${upper(var.env)})"
        description         = "Agent-facing portal for UC-12, UC-14, UC-15."
        app_type            = "regular_web"
        callbacks           = var.support_portal_callbacks
        allowed_logout_urls = var.support_portal_callbacks
        grant_types         = ["authorization_code", "refresh_token"]
        token_endpoint_auth = "client_secret_post"
        client_metadata     = { channel = "support", owner = "operations" }
      }

      support_m2m = {
        name                = "OLB Support Backend M2M (${upper(var.env)})"
        description         = "Calls the Auth0 Management API for support-initiated flows. Never exposed to a browser."
        app_type            = "non_interactive"
        grant_types         = ["client_credentials"]
        token_endpoint_auth = "client_secret_post"
        client_metadata     = { owner = "operations" }
      }
    },
    local.test_harness_enabled ? {
      test_harness = {
        name        = "ZZ Test Harness - Postman (${upper(var.env)})"
        description = "Non-production only. Enables password-realm and MFA grants so end-to-end flows can be driven headlessly before the front end exists."
        app_type    = "regular_web"
        callbacks   = ["https://oauth.pstmn.io/v1/callback", "http://localhost:3000/callback"]
        allowed_logout_urls = ["http://localhost:3000"]
        grant_types = [
          "authorization_code",
          "refresh_token",
          "password",
          "http://auth0.com/oauth/grant-type/password-realm",
          "http://auth0.com/oauth/grant-type/mfa-oob",
          "http://auth0.com/oauth/grant-type/mfa-otp",
          "http://auth0.com/oauth/grant-type/mfa-recovery-code"
        ]
        token_endpoint_auth = "client_secret_post"
        client_metadata     = { owner = "qa", nonprod_only = "true" }
      }
    } : {}
  )

  m2m_grants = {
    "support_m2m:mgmt" = {
      client_key = "support_m2m"
      audience   = local.mgmt_api_audience
      scopes = [
        "read:users",
        "update:users",
        "read:users_app_metadata",
        "update:users_app_metadata",
        "create:user_tickets",
        "read:logs",
        "read:logs_users",
        "delete:sessions",
        "read:attack_protection",
        "update:attack_protection"
      ]
    }

    "support_m2m:support_api" = {
      client_key = "support_m2m"
      audience   = module.apis.identifiers["support"]
      scopes = [
        "read:customer",
        "initiate:password_reset",
        "lock:customer",
        "unlock:customer",
        "read:audit"
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# Custom database connection - Fiserv DNA via the Private APIM facade
# ---------------------------------------------------------------------------
module "connection_dna" {
  source = "../../modules/b2c/connection_dna"

  connection_name          = local.connection_name
  display_name             = "Online Banking"
  import_mode              = var.import_mode
  legacy_migration_enabled = var.legacy_migration_enabled
  requires_username        = true
  apim_base_url            = var.apim_base_url
  apim_api_key             = var.apim_api_key

  enabled_clients = compact([
    module.clients.ids["olb_web"],
    module.clients.ids["olb_mobile"],
    module.clients.ids["support_portal"],
    # lookup(), not an index: the key genuinely does not exist in prod, and an
    # index into a missing key fails even inside a conditional.
    lookup(module.clients.ids, "test_harness", ""),
  ])
}

# ---------------------------------------------------------------------------
# Actions. Created here, bound in stacks/tenant.
# ---------------------------------------------------------------------------
module "actions" {
  source = "../../modules/b2c/actions"

  env                       = var.env
  runtime                   = var.actions_runtime
  b2c_connection_name       = local.connection_name
  apim_base_url             = var.apim_base_url
  apim_api_key              = var.apim_api_key
  action_signing_secret     = var.action_signing_secret
  email_collection_form_url = var.email_collection_form_url
  blocked_country_codes     = var.blocked_country_codes
  blocked_subdivisions      = var.blocked_subdivisions
  always_on_mfa             = var.always_on_mfa
  custom_claim_namespace    = var.custom_claim_namespace
}

# ---------------------------------------------------------------------------
# Roles and permissions
# ---------------------------------------------------------------------------
module "rbac" {
  source = "../../modules/b2c/rbac"

  roles = {
    olb_customer = {
      name        = "olb_customer"
      description = "Retail online banking customer."
      permissions = {
        (module.apis.identifiers["olb"]) = [
          "read:profile",
          "update:profile",
          "read:accounts",
          "manage:bill_payees",
          "manage:etransfer_recipients",
          "manage:interac_profile",
          "manage:cra_direct_deposit",
          "read:sessions",
          "revoke:sessions",
          "read:login_history"
        ]
      }
    }

    olb_delegate = {
      name        = "olb_delegate"
      description = "Delegate acting on another member's account with a reduced, time-bound scope set (UC-10)."
      permissions = {
        (module.apis.identifiers["olb"]) = [
          "read:profile",
          "read:accounts",
          "read:sessions"
        ]
      }
    }

    olb_delegated_admin = {
      name        = "olb_delegated_admin"
      description = "Business user who can create, modify and revoke delegates (UC-10)."
      permissions = {
        (module.apis.identifiers["olb"]) = [
          "read:profile",
          "update:profile",
          "read:accounts",
          "manage:delegates"
        ]
      }
    }

    support_agent = {
      name        = "support_agent"
      description = "Contact-centre agent. Can trigger a reset, lock and unlock (UC-12, UC-14, UC-15) but never reads a credential."
      permissions = {
        (module.apis.identifiers["support"]) = [
          "read:customer",
          "initiate:password_reset",
          "lock:customer",
          "unlock:customer",
          "read:audit"
        ]
      }
    }

    fraud_analyst = {
      name        = "fraud_analyst"
      description = "Read-only investigative access plus the ability to lock an account."
      permissions = {
        (module.apis.identifiers["support"]) = [
          "read:customer",
          "lock:customer",
          "read:audit"
        ]
      }
    }
  }
}
