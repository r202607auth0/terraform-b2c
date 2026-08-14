resource "auth0_resource_server" "this" {
  for_each = var.apis

  name                                            = each.value.name
  identifier                                      = each.value.identifier
  signing_alg                                     = each.value.signing_alg
  token_lifetime                                  = each.value.token_lifetime
  token_lifetime_for_web                          = each.value.token_lifetime_for_web
  allow_offline_access                            = each.value.allow_offline_access
  skip_consent_for_verifiable_first_party_clients = each.value.skip_consent_for_verifiable_first_party_clients
  enforce_policies                                = each.value.enforce_policies
  token_dialect                                   = each.value.token_dialect
}

# Scopes are managed by their own resource so that a scope added by an operator
# in the Dashboard is reconciled rather than silently kept.
resource "auth0_resource_server_scopes" "this" {
  for_each = var.apis

  resource_server_identifier = auth0_resource_server.this[each.key].identifier

  dynamic "scopes" {
    for_each = each.value.scopes
    content {
      name        = scopes.key
      description = scopes.value
    }
  }
}
