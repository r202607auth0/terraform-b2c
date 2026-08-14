resource "auth0_client" "this" {
  for_each = var.clients

  name                = each.value.name
  description         = each.value.description
  app_type            = each.value.app_type
  callbacks           = each.value.callbacks
  allowed_logout_urls = each.value.allowed_logout_urls
  allowed_origins     = each.value.allowed_origins
  web_origins         = each.value.web_origins
  grant_types         = each.value.grant_types
  oidc_conformant     = each.value.oidc_conformant
  sso                 = each.value.sso
  cross_origin_auth   = each.value.cross_origin_auth
  is_first_party      = true
  client_metadata     = merge(each.value.client_metadata, { environment = var.env })

  refresh_token {
    rotation_type                = each.value.refresh_token_rotation ? "rotating" : "non-rotating"
    expiration_type              = "expiring"
    leeway                       = 30
    token_lifetime               = 2592000 # 30 days absolute
    idle_token_lifetime          = each.value.idle_session_lifetime * 60
    infinite_token_lifetime      = false
    infinite_idle_token_lifetime = false
  }

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = 900
  }
}

# Auth Method is a separate resource in provider v1.x. Public clients (SPA /
# native) must be "none" so that PKCE is the only accepted proof.
resource "auth0_client_credentials" "this" {
  for_each = var.clients

  client_id                                = auth0_client.this[each.key].id
  authentication_method                    = each.value.token_endpoint_auth
}

resource "auth0_client_grant" "this" {
  for_each = var.m2m_grants

  client_id = auth0_client.this[each.value.client_key].id
  audience  = each.value.audience
  scopes    = each.value.scopes
}
