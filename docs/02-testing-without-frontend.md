# Testing before the front end exists

VeriChannel, the Private APIM and Fiserv DNA are all unavailable. This is how the
whole B2C estate gets exercised anyway.

## The three substitutions

| Missing | Substitute | Where |
|---|---|---|
| Fiserv DNA + VeriPark + APIM | Express mock behind a tunnel | `mocks/dna-mock/` |
| VeriChannel login UI | Auth0 Universal Login, hosted | nothing to build |
| VeriChannel BFF / API calls | Resource-owner password grant on the harness client | `postman/` |

Only the third is a compromise. The first is a faithful implementation of a
published contract, and the second is what production will use anyway.

## Setup

```bash
# 1. Mock, reachable from the internet
cd mocks/dna-mock && npm install
cp .env.example .env            # AUTH0_DOMAIN + support_m2m credentials
npm start                       # :4010
npx cloudflared tunnel --url http://localhost:4010

# 2. Point the tenant at it
#    environments/dev/b2c.tfvars:
#      apim_base_url             = "https://<tunnel>/identity/v1"
#      email_collection_form_url = "https://<tunnel>/forms/collect-email"
make apply ENV=dev STACK=b2c
make apply ENV=dev STACK=tenant

# 3. Wire Postman
make output ENV=dev STACK=b2c
```

Copy `client_ids.test_harness`, `client_ids.support_m2m` and
`role_ids.olb_delegated_admin` into `postman/OBP-B2C-dev.postman_environment.json`.
Client secrets are sensitive outputs:

```bash
terraform -chdir=stacks/b2c output -json | jq -r '.client_ids.value'
```

## Running

```bash
newman run postman/OBP-B2C-E2E.postman_collection.json \
  -e postman/OBP-B2C-dev.postman_environment.json
```

Run **00 - Setup** first: it resets the mock to seed state, so the folders are
order-independent after that.

## What is covered and what is not

| Use case | Headless | Notes |
|---|---|---|
| UC-01 Registration | Full | Custom signup **field** needs the real UI |
| UC-02 Login | Most | Geo blocking is indirect - verify in a browser |
| UC-03 Legacy login | Partial | Import is covered; the redirect leg is browser-only |
| UC-04 Step-up | Partial | The `/authorize` leg is browser-only |
| UC-05 MFA | Full | Reading the emailed code is manual in dev |
| UC-06 Lockout | Full | |
| UC-07 SSPR | Most | Completing the reset needs the emailed link |
| UC-08 Profile | Full | |
| UC-09 Sessions | Full | |
| UC-10 Delegation | Full | Expiry enforcement is not yet built |
| UC-11 Notifications | Full | Asserted against the mock ledger |
| UC-12 / 14 / 15 Support | Full | |

Three requests are marked **BROWSER STEP**. They exercise `api.redirect` and
interactive step-up, which have no headless equivalent. Open them in a browser
rather than pressing Send.

## The redirect limitation, in detail

`api.redirect.sendUserTo` needs a user agent. The password grant has none. Without
a guard, every headless UC-03 test fails on an unhelpful runtime error, so the
Action detects the non-interactive grant and stamps
`app_metadata.email_collection_required` instead:

```js
const interactive = Boolean(event.transaction) && event.request.method !== 'POST';
if (!interactive) {
  api.user.setAppMetadata('email_collection_required', true);
  return;
}
```

The Postman folder asserts the flag. The browser step asserts the redirect. Both
are needed; neither alone is sufficient.

## Reading OTP codes in CI

Dev: take the code from the Auth0 log stream or the mailbox and paste it into
`email_otp_code`.

CI: point the tenant's email provider at a disposable-inbox service (Mailosaur,
MailSlurp) and fetch it in a pre-request script. That is the difference between a
suite that runs unattended and one that needs a human every time.

## The day APIM becomes available

1. Point `apim_base_url` at the real endpoint in `environments/qa/b2c.tfvars`.
2. Swap `x-api-key` for the production auth scheme in
   `modules/b2c/connection_dna/scripts/*.js` and the Actions.
3. `make apply ENV=qa STACK=b2c`.
4. Run the same collection against qa.

Nothing else changes. That is the point of writing the contract before the mock.
