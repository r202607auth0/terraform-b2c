# UC-03 - Legacy User Login

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 4.10 - 4.12
**Status:** implemented; the redirect leg needs the VeriChannel screen

## Scope

Existing online banking customers live in Fiserv DNA, are identified by
**username** rather than email, and may have no email address on file. They must
be migrated to Auth0 without a password reset campaign, and an email address must
be collected and proven before they reach the application.

## The migration model

`import_mode = true` on the custom database connection gives trickle migration:

```
first login  ->  Auth0 has no record  ->  login.js  ->  APIM -> VeriLink -> DNA
             ->  200 + profile        ->  Auth0 imports user AND password hash
second login ->  Auth0 has the record ->  DNA is never called again
```

This is why `requires_username = true` on the connection: until the population
has drained, the identifier may be a username.

When the legacy population reaches zero, set `legacy_migration_enabled = false`.
The scripts short-circuit, `login.js` stops calling the core, and the connection
can later be flipped to `import_mode = false`.

## Functional flow

1. Customer signs in with their legacy username and password.
2. Auth0 has no such user, so `login.js` calls `POST /credentials/authenticate`.
3. On `200` the profile is imported with `app_metadata.legacy = true` and
   `email_on_file` reflecting the core. On `401` the message is the same as any
   wrong password. On `423` the script returns a generic unauthorised error - the
   caller learns nothing about the lock.
4. **Action 02 - legacy email collection** runs. If the user is legacy and has no
   email on file, it mints a 10-minute signed session token and redirects to the
   collection form.
5. The form asks for an address, checks `GET /credentials/email-in-use`, and on a
   clash asks for a different one.
6. An OTP proves ownership of the address.
7. The form writes the address to the core, sets the primary email on the Auth0
   user through the Management API, then returns to `https://{domain}/continue`
   with a signed token.
8. `onContinuePostLogin` validates the token, re-checks the address is still
   free, and stamps `email_collected = true`.
9. MFA enrolment follows (UC-05), then the customer continues to the application.

## Why the form calls the Management API

The Actions runtime cannot change the primary email of a database user. Something
outside the Action has to make that write. In this repo it is the mock form
backend; in production it belongs to VeriLink, using a dedicated M2M client with
`update:users` only. Do not reuse `support_m2m` for it - different blast radius.

## Terraform and code

```
modules/b2c/actions/scripts/post-login/02-legacy-email-collection.js
modules/b2c/connection_dna/scripts/login.js
modules/b2c/connection_dna/scripts/get_user.js
modules/b2c/connection_dna/main.tf              # import_mode, requires_username
mocks/dna-mock/server.js                        # the stand-in form, /forms/collect-email
```

## Testing before the front end exists

**Headless (Postman folder UC-03).** `api.redirect` does not exist in the
resource-owner password grant, so the Action detects a non-interactive grant and
sets `app_metadata.email_collection_required = true` instead of redirecting.
Without that guard every headless test would fail on an unhelpful runtime error.
The Postman folder asserts the flag through the Management API.

**Browser (manual, one request marked BROWSER STEP).** Open the `/authorize` URL,
sign in as `jdoe1978` / `Legacy#Pass2019`, and walk the redirect. The OTP is
printed to the mock console and served at `GET {mock_base_url}/_admin/otp/<user-id>`.
This stays a manual gate until VeriChannel ships the screen - it is the only path
that exercises the redirect contract.

## Acceptance criteria

- [ ] A legacy username plus correct password issues tokens on the first attempt.
- [ ] The imported user carries `legacy = true` and the correct CIF.
- [ ] The second login does not reach the core (check `/_admin/events`).
- [ ] A legacy user with no email is redirected to the collection form.
- [ ] An address already in use is rejected with a retry, not an error page.
- [ ] Ownership is proven by OTP before the address is written.
- [ ] After collection, the address is the primary email on the Auth0 user and is verified.
- [ ] The form is bilingual and meets WCAG 2.1 AA.

## Decisions to confirm with the client

1. **Where the collection screen lives.** The mock is a stand-in. VeriChannel
   hosting it keeps branding consistent; Auth0 Forms would avoid a round trip but
   adds a licence dependency.
2. **Username retirement.** Once an email is collected, should the legacy username
   remain a valid identifier? Keeping both is friendlier; retiring the username
   simplifies support and closes an enumeration surface. Recommend keeping both
   for one year, then retiring.
