# Partial backend configuration. The bucket, key and region are supplied per
# environment from environments/<env>/<stack>.backend.hcl:
#
#   terraform -chdir=stacks/b2c init -reconfigure \
#     -backend-config=../../environments/dev/b2c.backend.hcl
terraform {
  backend "s3" {}
}
