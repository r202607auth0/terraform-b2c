# Credentials come from the environment so that nothing secret is ever written
# to a .tfvars file or to state input:
#   AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET
provider "auth0" {
  debug = false
}
