# UC-02 - New User Login

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 4.5 - 4.9
**Status:** implemented in code

## Scope

A customer whose credential lives in Auth0 signs in. Every access-control
decision - deny lists, sanctioned geographies, email verification, risk-based
MFA - is made in the post-login chain.

## Preconditions

- The user exists in `OLB-B2C-DNA`, either registered through UC-01 or imported
  through UC-03.
- Post-login Actions are bound in this order: access-control, legacy-email-collection,
  adaptive-MFA, custom-claims.

## Functional flow

1. VeriChannel's BFF starts an authorization code flow with PKCE. Consumer mobile
   apps cannot hold a secret, so the BFF pattern is not optional for web; the
   mobile client is public and relies on PKCE alone.
2. Identifier-first Universal Login collects the email or username, then the password.
3. Auth0 validates the credential against its own store.
4. **Action 01 - access control** denies when any of these hold:
   - `app_metadata.blocked` is true or a `blocked_reason` is present (see UC-14);
   - the request's country is in the blocked list (KP, IR, RU, MM, SY, CU) or the
     subdivision is blocked (UA-43, Crimea);
   - the user is not legacy and `email_verified` is false;
   - `dna_status` is no longer `active`.
5. **Action 03 - adaptive MFA** decides whether to challenge. See UC-04/UC-05.
6. **Action 04 - custom claims** writes the namespaced claims the APIM and
   VeriLink consume.
7. Tokens are issued: a 15-minute access token, a rotating refresh token with a
   30-minute idle window and a 30-day absolute cap.

## Auth0 building blocks

| Requirement | Mechanism |
|---|---|
| Req-1 credential validation | Database connection |
| Req-3 banned user / IP / geo | Action 01, `event.request.geoip` |
| Req-3 rate limiting | `auth0_attack_protection.suspicious_ip_throttling` |
| Req-3 risk signals | `event.authentication.riskAssessment` in Action 03 |
| Req-4 adaptive MFA | `always_on_mfa` variable selects always-on vs risk-based |
| Req-5 email verification | Action 01 |
| Session timeout | Client `refresh_token` block + tenant session lifetime |

## Terraform and code

```
modules/b2c/actions/scripts/post-login/01-access-control.js
modules/b2c/actions/scripts/post-login/03-adaptive-mfa.js
modules/b2c/actions/scripts/post-login/04-custom-claims.js
modules/tenant/attack_protection/main.tf
stacks/b2c/main.tf                              # client token lifetimes
```

## Token shape

Every claim is namespaced under `https://obp.ca/claims`:

| Claim | Meaning |
|---|---|
| `/cif` | Core customer identifier |
| `/customer_type` | `bank` or `trust` |
| `/member_id` | DNA member id |
| `/legacy` | Imported from the legacy store rather than registered |
| `/language` | `en` or `fr-CA` |
| `/roles` | RBAC roles |
| `/amr` | Authentication methods actually used |
| `/acr` | `...multi-factor` once a second factor has been satisfied |

Consumers must read these claims rather than raw metadata. Auth0 does not put
`app_metadata` in tokens, and that should not be relied on changing.

## Testing before the front end exists

Postman folder **UC-02** drives login through the password-realm grant on the
test harness client, then decodes the ID token and asserts on each claim.

Geo blocking is the awkward one. `auth0-forwarded-for` is honoured only when the
client has "Trust Token Endpoint IP Header" enabled, and even then the assertion
is indirect. Verify the rule in a browser through a VPN before sign-off.

## Acceptance criteria

- [ ] A correct credential from an allowed geography issues tokens.
- [ ] A wrong password is indistinguishable from an unknown identifier.
- [ ] A login from a blocked country is denied with a non-specific message.
- [ ] An unverified, non-legacy user cannot sign in.
- [ ] The ID token carries every claim in the table above.
- [ ] Repeated failures trigger throttling (see UC-06).

## Decisions to confirm with the client

1. **`always_on_mfa`.** Set to `false` in dev/qa so tests are not blocked, `true`
   in staging/prod. If the business wants risk-based only in production, the
   fraud team must accept that low-risk logins proceed with one factor.
2. **Geo source of truth.** `event.request.geoip` is Auth0's MaxMind lookup. If
   the fraud team already runs a geo/IP reputation service through Feedzai,
   consider calling that instead so one list governs both channels.
