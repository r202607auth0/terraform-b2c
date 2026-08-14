# Environment bootstrap

What has to exist before the first `terraform apply`.

## 1. State backend

One bucket per environment, versioned, encrypted, public access blocked.

```bash
for ENV in dev qa staging prod; do
  aws s3api create-bucket \
    --bucket obp-identity-tfstate-$ENV \
    --region ca-central-1 \
    --create-bucket-configuration LocationConstraint=ca-central-1

  aws s3api put-bucket-versioning \
    --bucket obp-identity-tfstate-$ENV \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket obp-identity-tfstate-$ENV \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'

  aws s3api put-public-access-block \
    --bucket obp-identity-tfstate-$ENV \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
done
```

Versioning is what lets you recover from a bad apply. It is not optional.

The backend blocks use `use_lockfile = true` (S3-native locking), so no DynamoDB
table is needed. On an older Terraform, add `dynamodb_table` to each
`backend.hcl` instead.

## 2. Auth0 Terraform principal

One M2M application per tenant, named so it is obvious in the audit log
(`terraform-obp-dev`). Authorise it against the Management API with:

```
read:clients create:clients update:clients delete:clients
read:client_keys create:client_credentials update:client_credentials
read:client_grants create:client_grants update:client_grants delete:client_grants
read:resource_servers create:resource_servers update:resource_servers delete:resource_servers
read:connections create:connections update:connections delete:connections
read:actions create:actions update:actions delete:actions
read:roles create:roles update:roles delete:roles
read:email_templates create:email_templates update:email_templates
read:email_provider create:email_provider update:email_provider
read:branding update:branding
read:prompts update:prompts
read:attack_protection update:attack_protection
read:guardian_factors update:guardian_factors
read:triggers update:triggers
read:tenant_settings update:tenant_settings
```

Rotate the secret on the same cadence as any other production credential, and
store it only in the CI secret store.

## 3. GitHub configuration

**Repository secrets** (per Environment, not repository-wide - dev credentials
must not be reachable from a prod job):

| Secret | Purpose |
|---|---|
| `AUTH0_DOMAIN` | Tenant domain |
| `AUTH0_CLIENT_ID` | Terraform principal |
| `AUTH0_CLIENT_SECRET` | Terraform principal |
| `APIM_API_KEY` | Identity facade key |
| `ACTION_SIGNING_SECRET` | UC-03 redirect token signing |
| `AWS_TF_ROLE_ARN` | Role assumed via OIDC for the state backend |
| `TEST_HARNESS_CLIENT_ID` | Newman, non-prod only |
| `TEST_HARNESS_CLIENT_SECRET` | Newman, non-prod only |

**Environments:** `dev`, `qa`, `staging`, `prod`. Add required reviewers to
staging and prod - that is the approval gate the plan asks for.

**AWS OIDC trust policy** so no long-lived keys exist:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*" }
  }
}
```

## 4. Secret generation

```bash
openssl rand -hex 32   # ACTION_SIGNING_SECRET, one per environment
```

Never share it across environments: a dev secret leaking would otherwise let
someone mint a valid continue-token against production.

## 5. First apply

```bash
export AUTH0_DOMAIN=obp-dev.ca.auth0.com
export AUTH0_CLIENT_ID=...
export AUTH0_CLIENT_SECRET=...
export TF_VAR_apim_api_key='dev-mock-key'
export TF_VAR_action_signing_secret="$(openssl rand -hex 32)"

make plan  ENV=dev STACK=b2c     # read it properly
make apply ENV=dev STACK=b2c
make apply ENV=dev STACK=tenant
```

Read the first plan line by line. On a shared tenant the thing to look for is any
`destroy` or `replace` against a resource you did not expect to own - that is B2B
configuration about to be taken over.

## 6. Importing existing resources

If B2B already manages something `stacks/tenant` also declares:

```bash
terraform -chdir=stacks/tenant import \
  'module.attack_protection.auth0_attack_protection.this' \
  "$AUTH0_DOMAIN"

terraform -chdir=stacks/tenant import \
  'module.mfa.auth0_guardian.this' \
  "$AUTH0_DOMAIN"
```

Tenant singletons import by domain, since they have no id of their own. If both
stacks genuinely need to manage a resource, one of them has to stop - remove the
module from `stacks/tenant` rather than living with the conflict.
