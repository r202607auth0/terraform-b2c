resource "auth0_role" "this" {
  for_each = var.roles

  name        = each.value.name
  description = each.value.description
}

locals {
  # Flatten role => audience => scopes into one addressable list per role.
  role_permissions = {
    for role_key, role in var.roles : role_key => flatten([
      for audience, scopes in role.permissions : [
        for scope in scopes : {
          audience = audience
          scope    = scope
        }
      ]
    ])
  }
}

resource "auth0_role_permissions" "this" {
  for_each = var.roles

  role_id = auth0_role.this[each.key].id

  dynamic "permissions" {
    for_each = local.role_permissions[each.key]
    content {
      resource_server_identifier = permissions.value.audience
      name                       = permissions.value.scope
    }
  }
}
