# OBP B2C Identity - Auth0 + Terraform

Phase 3 of the Online Banking Identity Architecture: fourteen B2C use cases on an
Auth0 tenant that already carries a working B2B configuration, managed entirely
in Terraform, tested end to end **before** VeriChannel, the Private APIM or
Fiserv DNA exist.

---

## The problem this repo solves

Three of the four systems in the integration are unavailable:

```
  OLB frontend (VeriChannel)   -- not ready
  Private APIM (Azure)         -- not ready
  Fiserv DNA (core banking)    -- not ready
  Auth0                        -- available, B2B already configured
```

The naive response is to wait. Instead, the integration boundary is written down
as a contract first (`mocks/openapi/private-apim-identity.yaml`), a mock
implements it, and a non-production test-harness client makes every flow drivable
from Postman with no browser. When the real systems arrive, one variable changes:
`apim_base_url`.

---

## Layout

```
modules/
  b2c/
    apis/               resource servers + scopes
    clients/            web BFF, mobile, support portal, M2M, test harness
    connection_dna/     custom DB connection + the six scripts
    actions/            5 Actions - created here, bound in stacks/tenant
    rbac/               roles and permissions
  tenant/               tenant singletons - shared with B2B, handle with care
    attack_protection/  UC-06 lockout
    mfa/                UC-05 factors (Guardian)
    experience/         branding, bilingual prompts, email templates
    trigger_bindings/   the ONLY place auth0_trigger_actions may live

stacks/
  b2c/                  composition root for the B2C estate
  tenant/               composition root for tenant singletons

environments/
  dev|qa|staging|prod/  <stack>.backend.hcl + <stack>.tfvars

mocks/
  openapi/              the contract - hand this to VeriPark and Fiserv
  dna-mock/             Express implementation + the UC-03 form
  beeceptor/            hosted-rules alternative

postman/                55 requests across 10 folders, one per use case group
docs/
  use-cases/            UC-01 .. UC-15, one file each
  00-architecture-decisions.md
  02-testing-without-frontend.md
  03-traceability-matrix.md
```

### Why the layout differs from the B2B stack

The B2B stack keeps a `modules/` copy inside each environment directory. That
works, but a fix has to be applied four times. Here the modules are shared and
each environment contributes only a `.tfvars` and a `.backend.hcl`. If you would
rather mirror the existing convention exactly, copy `stacks/b2c` into each
environment directory and change the `source` paths - nothing else depends on the
layout.

---

## Step-by-step

### Step 1 - Prerequisites

- Terraform >= 1.6
- Node 18+ (for the mock and for `node --check` in CI)
- An S3 bucket per environment with versioning enabled, for state
- An Auth0 **Machine-to-Machine** application authorised against the Management
  API with the scopes Terraform needs

```bash
# One per environment. Terraform authenticates as this application.
export AUTH0_DOMAIN=obp-dev.ca.auth0.com
export AUTH0_CLIENT_ID=...
export AUTH0_CLIENT_SECRET=...
```

Minimum Management API scopes for the Terraform principal:
`read/create/update/delete` on `clients`, `client_grants`, `resource_servers`,
`connections`, `actions`, `roles`, `rules`, `email_templates`, `email_provider`,
`branding`, `prompts`, `attack_protection`, `guardian`, `triggers`.

### Step 2 - Confirm what B2B already owns

The tenant is shared. Before the first apply, find out which tenant singletons the
B2B stack manages, because `stacks/tenant` wants to manage them too:

```bash
auth0 login --domain $AUTH0_DOMAIN
auth0 actions list --json | jq '.[] | {id, name, supported_triggers}'
auth0 api get "triggers/post-login/bindings" | jq '.bindings[] | .action.name'
auth0 api get "emails/provider" | jq '.name'
```

Then:

- Put the B2B post-login Action ids into `b2b_post_login_actions` in
  `environments/<env>/tenant.tfvars`. Getting this wrong is the one mistake that
  can break B2B logins - `stacks/tenant` writes the complete binding list, so an
  Action missing from that list is an Action removed from the trigger.
- If B2B already owns `auth0_email_provider`, leave `manage_email_provider = false`.
- If B2B owns `auth0_tenant` or `auth0_attack_protection`, either import them here
  or remove the corresponding module from `stacks/tenant`. Two stacks owning one
  singleton is a fight on every apply.

Better still, if the B2B stack can export `post_login_actions` as an output, set
`b2b_state_key` and the composition happens automatically.

### Step 3 - Start the mock

```bash
cd mocks/dna-mock
npm install
cp .env.example .env          # AUTH0_DOMAIN + support_m2m credentials (step 6)
npm start                     # http://localhost:4010
```

Auth0 calls the mock from the internet, so it needs a public URL:

```bash
npx cloudflared tunnel --url http://localhost:4010
# -> https://random-words-1234.trycloudflare.com
```

Set both URLs in `environments/dev/b2c.tfvars`:

```hcl
apim_base_url             = "https://random-words-1234.trycloudflare.com/identity/v1"
email_collection_form_url = "https://random-words-1234.trycloudflare.com/forms/collect-email"
```

The tunnel URL changes on restart. For a stable dev loop, use a named Cloudflare
tunnel or a paid ngrok domain - re-applying Terraform on every mock restart gets
old quickly.

### Step 4 - Deploy the B2C stack

```bash
export TF_VAR_apim_api_key='dev-mock-key'
export TF_VAR_action_signing_secret="$(openssl rand -hex 32)"

make plan  ENV=dev STACK=b2c
make apply ENV=dev STACK=b2c
```

Creates: two resource servers with their scopes, five clients, the custom
database connection with its six scripts, seven Actions (unbound), five roles.

### Step 5 - Deploy the tenant stack

**Order matters.** `stacks/tenant` reads `stacks/b2c`'s remote state for the
Action ids.

```bash
make apply ENV=dev STACK=tenant
```

Creates: attack protection (3-attempt lockout), Guardian factors, branding,
bilingual prompt text, four email templates, and the trigger bindings.

Verify the bindings:

```bash
auth0 api get "triggers/post-login/bindings" | jq '.bindings[].action.name'
# expect B2B actions first, then:
#   b2c-post-login-01-access-control
#   b2c-post-login-02-legacy-email-collection
#   b2c-post-login-03-adaptive-mfa
#   b2c-post-login-04-custom-claims
```

### Step 6 - Wire up Postman

```bash
make output ENV=dev STACK=b2c
```

Copy into `postman/OBP-B2C-dev.postman_environment.json`:

| Terraform output | Postman variable |
|---|---|
| `client_ids.test_harness` | `harness_client_id` |
| `client_ids.support_m2m` | `support_m2m_client_id` |
| `role_ids.olb_delegated_admin` | `role_delegated_admin_id` |
| tunnel URL | `mock_base_url` |

Secrets come from the Dashboard or:

```bash
auth0 apps show <client_id> --json | jq -r .client_secret
```

Put the `support_m2m` credentials into `mocks/dna-mock/.env` too - the UC-03 form
uses them to set the primary email on the Auth0 user.

### Step 7 - Run the suite

```bash
newman run postman/OBP-B2C-E2E.postman_collection.json \
  -e postman/OBP-B2C-dev.postman_environment.json
```

Run **00 - Setup** first; it resets the mock to seed state.

Three requests are marked **BROWSER STEP** - `api.redirect` and interactive
step-up have no headless equivalent. Open those URLs in a browser.

### Step 8 - Promote

```bash
make apply ENV=qa      STACK=b2c && make apply ENV=qa      STACK=tenant
make apply ENV=staging STACK=b2c && make apply ENV=staging STACK=tenant
make apply ENV=prod    STACK=b2c && make apply ENV=prod    STACK=tenant
```

In CI the approval gate is a GitHub Environment protection rule on the `apply`
job. Staging and prod set `always_on_mfa = true` and never create the test
harness client - `stacks/b2c` refuses to build it when `env == "prod"` whatever
the tfvars say.

---

## Use case index

| UC | Title | Plan tasks | Doc |
|---|---|---|---|
| 01 | User Registration | 4.0-4.4 | [UC-01](docs/use-cases/UC-01-user-registration.md) |
| 02 | New User Login | 4.5-4.9 | [UC-02](docs/use-cases/UC-02-new-user-login.md) |
| 03 | Legacy User Login | 4.10-4.12 | [UC-03](docs/use-cases/UC-03-legacy-user-login.md) |
| 04 | Step-Up Authentication | 5.0-5.2 | [UC-04](docs/use-cases/UC-04-step-up-authentication.md) |
| 05 | MFA Factors | 5.3-5.5 | [UC-05](docs/use-cases/UC-05-mfa-factors.md) |
| 06 | Account Lockout | 5.6-5.8 | [UC-06](docs/use-cases/UC-06-account-lockout.md) |
| 07 | Self-Service Password Reset | 5.9-5.11 | [UC-07](docs/use-cases/UC-07-self-service-password-reset.md) |
| 08 | User Profile Management | 6.0-6.2 | [UC-08](docs/use-cases/UC-08-user-profile-management.md) |
| 09 | Session / Device Activity | 6.3-6.4 | [UC-09](docs/use-cases/UC-09-session-device-activity.md) |
| 10 | Delegated Admin | 6.5-6.6 | [UC-10](docs/use-cases/UC-10-delegated-admin.md) |
| 11 | User Notifications | 6.7 | [UC-11](docs/use-cases/UC-11-user-notifications.md) |
| 12 | Support-Initiated Password Reset | 7.0-7.1 | [UC-12](docs/use-cases/UC-12-support-initiated-password-reset.md) |
| 14 | Support-Initiated Lockout | 7.4 | [UC-14](docs/use-cases/UC-14-support-initiated-lockout.md) |
| 15 | Support-Initiated Unblock | 7.5 | [UC-15](docs/use-cases/UC-15-support-initiated-unblock.md) |

---

## The seven things most likely to bite

1. **Two stacks binding one trigger.** Only `stacks/tenant` may declare
   `auth0_trigger_actions`. If the B2B stack also declares it, every apply
   removes the other side's Actions and MFA "randomly stops working".
2. **A missing B2B Action in `b2b_post_login_actions`.** The binding list is
   authoritative. Omitting an Action removes it from the trigger.
3. **A missing connection guard.** Every Action starts with
   `if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) return;`. Drop
   it and B2C logic runs on B2B logins.
4. **Apply order.** `b2c` before `tenant`, always.
5. **The tunnel URL changing.** Auth0 keeps calling the old one and every legacy
   login fails with an APIM-unreachable error.
6. **The test harness in prod.** Guarded in code, but check `terraform plan`
   output before every production apply anyway.
7. **`import_mode` flipped too early.** Setting it to `false` while legacy users
   remain locks them out with no path back except a reset campaign.

---

## Open items

Carried in the use case docs, gathered here for the governance gate:

| Item | UC | Why it matters |
|---|---|---|
| Delegation expiry enforcement is not built | UC-10 | Roles have no expiry; a stale delegation grants live access |
| MFA-failure account lockout is not automatic | UC-06 | The requirement asks for it; Auth0's counter covers passwords only |
| Log streaming destination undecided | UC-09 | Auth0 retention is shorter than any regulated requirement |
| VeriChannel BFF assumed to exist | AD-06 | If VeriChannel is a SPA with no server tier, the client model changes |
| Identity proofing depth at registration | UC-01 | CIF alone means an account number is enough to start registration |
| APIM auth scheme | AD-08 | `x-api-key` is a dev stand-in; production needs mTLS or client credentials |

---

## Commands

```bash
make help                                 # what is available
make validate                             # fmt + validate every stack
make plan   ENV=dev STACK=b2c
make apply  ENV=dev STACK=tenant
make output ENV=dev STACK=b2c
make drift  ENV=prod STACK=tenant         # exit 2 means drift
```
