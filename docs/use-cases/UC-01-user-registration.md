# UC-01 - User Registration

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 4.0 - 4.4
**Status:** implemented in code, blocked on the real core for end-to-end sign-off

## Scope

A member who already exists in Fiserv DNA but has no online banking profile
creates one. The account number (CIF) is the proof of membership; Auth0 becomes
the owner of the credential from this moment on.

**Actors:** OLB Customer (prospective), Auth0, Private APIM, VeriPark VeriLink, Fiserv DNA

## Preconditions

- The member exists in DNA with `status = active` and is not already enrolled.
- The custom database connection `OLB-B2C-DNA` is deployed and enabled for the
  `olb_web` and `olb_mobile` clients.
- The pre-user-registration Action is bound to the trigger by `stacks/tenant`.

## Functional flow

1. Customer selects **Register** in VeriChannel; the BFF starts an `/authorize`
   with `screen_hint=signup`.
2. The signup screen collects the account number, surname, email address and a
   new password. The account number field is added through a custom signup field
   on the Universal Login signup prompt.
3. Auth0 fires **pre-user-registration**. The Action reads the CIF from
   `user_metadata`, calls `POST /members/verify-cif`, and:
   - `404` -> deny, "we could not match that account number";
   - `409` -> deny, "a profile already exists, try signing in";
   - `status != active` -> deny, "not eligible";
   - APIM unreachable -> **deny**. Registration fails closed.
4. On success the Action stamps `app_metadata` with `cif`, `customer_type`
   (`bank` for 5 digits, `trust` for 6), `member_id`, `dna_status`, and removes
   the CIF from `user_metadata` so the customer can never edit it.
5. The database connection's `create` script posts the enrolment to
   `POST /enrollments` with an idempotency key. The password is **not** sent.
6. Auth0 sends the `verify_email` template. The customer clicks through; the
   `verify` script propagates the verified state to the core.
7. The customer is required to enrol an MFA factor before first use - see
   [UC-05](UC-05-mfa-factors.md).
8. Confirmation is sent to the verified address.

## Auth0 building blocks

| Concern | Mechanism |
|---|---|
| Capture the CIF | Custom signup field on the `signup` prompt -> `user_metadata.cif` |
| Validate the CIF | Action, `pre-user-registration` trigger, v2 |
| Bank vs trust | CIF length, cross-checked against `customerType` from the core |
| Credential storage | Auth0 database connection, `enabled_database_customization = true` |
| Enrolment write-back | `create.js` custom database script |
| Activation email | `auth0_email_template.verify_email`, bilingual |
| Password rules | `password_policy = "excellent"` + `min_length = 12` + history 24 |

## Terraform and code

```
modules/b2c/actions/scripts/pre-user-registration/cif-validation.js
modules/b2c/connection_dna/scripts/create.js
modules/b2c/connection_dna/main.tf              # password policy, history, complexity
modules/tenant/experience/templates/verify_email.html
modules/tenant/experience/templates/prompt-signup-*.json
```

## Integration contract

| Call | Endpoint | Failure behaviour |
|---|---|---|
| Validate CIF | `POST /members/verify-cif` | Fail closed - deny registration |
| Record enrolment | `POST /enrollments` | 409 surfaces as "already enrolled" |
| Confirm verification | `POST /credentials/{identifier}/verify` | Logged, non-blocking |

## Testing before the front end exists

Postman folder **UC-01**. The five signup requests cover the happy path for both
customer types and the three denial paths. `GET {mock_base_url}/_admin/events?kind=enrollment`
proves the write reached the core.

The one thing Postman cannot cover is the custom signup **field**: `/dbconnections/signup`
accepts `user_metadata` directly, so the CIF arrives without any UI. Once
VeriChannel exists, re-verify that the field maps to `user_metadata.cif` and
nowhere else.

## Acceptance criteria

- [ ] A valid, un-enrolled, active CIF produces exactly one Auth0 user and one core enrolment.
- [ ] An unknown, dormant or already-enrolled CIF produces no Auth0 user.
- [ ] The CIF is present in `app_metadata` and absent from `user_metadata`.
- [ ] 5-digit CIFs resolve to `customer_type = bank`, 6-digit to `trust`.
- [ ] The activation email is sent to the address the customer supplied, in their language.
- [ ] Passwords shorter than 12 characters, or missing a character class, are rejected.
- [ ] Registration screens meet WCAG 2.1 AA in English and Canadian French.

## Decisions to confirm with the client

1. **Identity proofing depth.** The contract accepts an optional surname and date
   of birth alongside the CIF. Sending only the CIF means anyone holding an
   account number can start a registration. Recommend requiring at least two
   factors of proof, and rate-limiting `verify-cif` at APIM.
2. **Fail-closed on core outage.** Currently an APIM timeout blocks registration.
   The alternative - queue and reconcile - creates an unverified identity, which
   is worse. Confirm the business accepts the outage behaviour.
