# DNA mock

Stands in for **Azure Private APIM -> VeriPark VeriLink -> Fiserv DNA** and hosts
the UC-03 email-collection form.

```bash
cd mocks/dna-mock
cp .env.example .env      # fill in AUTH0_DOMAIN + support_m2m credentials
npm install
npm start                 # http://localhost:4010
```

Auth0 has to reach it from the internet, so put a tunnel in front:

```bash
npx cloudflared tunnel --url http://localhost:4010
# -> https://random-words-1234.trycloudflare.com
```

Then set in `environments/dev/b2c.tfvars`:

```hcl
apim_base_url             = "https://random-words-1234.trycloudflare.com/identity/v1"
email_collection_form_url = "https://random-words-1234.trycloudflare.com/forms/collect-email"
```

and `make apply ENV=dev STACK=b2c`.

## Seeded members

| CIF | Identifier | Password | Exercises |
|---|---|---|---|
| 12345 | - | - | UC-01 bank customer, 5-digit CIF |
| 678901 | - | - | UC-01 trust customer, 6-digit CIF, fr-CA |
| 11111 | - | - | UC-01 negative: already enrolled (409) |
| 99999 | - | - | UC-01 negative: dormant, not eligible |
| 24680 | `jdoe1978` | `Legacy#Pass2019` | UC-03 legacy, **no email on file** |
| 13579 | `mtremblay` | `Legacy#Pass2019` | UC-02/03 legacy with verified email |
| 55555 | `lockeduser` | `Legacy#Pass2019` | UC-06 core-side lock (423) |

## Inspection endpoints

| Endpoint | Purpose |
|---|---|
| `GET /_admin/events` | Everything Auth0 has sent, newest last. `?kind=security-event` filters. |
| `GET /_admin/members` | Current member state after mutations |
| `GET /_admin/otp/<auth0-user-id>` | The UC-03 code a human would read in an inbox |
| `POST /_admin/reset` | Back to seed. Call this between Postman runs. |

`/_admin` is unauthenticated on purpose so Postman assertions stay short. It must
never exist outside a developer laptop or an ephemeral CI container.

## Beeceptor alternative

If you cannot run a tunnel, `mocks/beeceptor/rules.json` covers the read paths
(`verify-cif`, `authenticate`, `credentials/{id}`) with static responses. It is
enough for UC-01 and UC-02 but not for UC-03, which needs the stateful form.
