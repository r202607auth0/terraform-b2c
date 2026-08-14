# UC-07 - Self-Service Password Reset

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 5.9 - 5.11
**Status:** implemented in code

## Scope

Forgot Password sends a one-time link to the verified email address. The customer
sets a new password meeting policy, and the account lockout from UC-06 is lifted.

## Functional flow

1. Customer selects **Forgot password** and enters their identifier.
2. Auth0 responds identically whether or not the identifier exists. This is what
   satisfies "no PII revealed to an unauthorised user" - the two Postman requests
   that prove it sit next to each other in the folder for exactly that reason.
3. The `reset_email` template is sent, `url_lifetime_in_seconds = 900`.
4. The customer sets a new password. Policy is enforced by the connection:
   - at least 12 characters,
   - `password_policy = "excellent"` requires upper, lower, digit and special,
   - `password_history` size 24 blocks reuse,
   - `password_no_personal_info` blocks name and email fragments,
   - `password_dictionary` blocks common passwords,
   - breached-password detection blocks known-compromised passwords.
5. For a user still in the legacy store, `change_password.js` pushes the new
   password to the core and clears the core-side lock.
6. The **password-reset-post-challenge** Action posts `PASSWORD_RESET_COMPLETED`
   to the core, giving an audit record outside Auth0.
7. The Auth0 brute-force block is cleared by the successful reset.

## The 15-minute link

`url_lifetime_in_seconds = 900` in `modules/tenant/experience/main.tf`, and
`ttl_sec: 900` on support-initiated tickets in UC-12. Both places, or the two
paths drift.

## Terraform and code

```
modules/tenant/experience/main.tf               # reset_email, 900s lifetime
modules/b2c/connection_dna/main.tf              # complexity, history, dictionary
modules/b2c/connection_dna/scripts/change_password.js
modules/b2c/actions/scripts/password-reset-post-challenge/unlock-and-notify.js
```

## Testing before the front end exists

Postman folder **UC-07**:

- request a reset for a known address, then for an unknown one, and assert the
  responses are indistinguishable;
- attempt a signup with `password1` and assert the policy rejects it;
- create a support ticket with `ttl_sec: 900` and assert the URL comes back;
- read `/_admin/events` and assert the core was told.

Completing a reset needs the emailed link, so full end-to-end is manual in dev.
For CI, point the tenant email provider at a disposable-inbox service and fetch
the link in a pre-request script.

## Acceptance criteria

- [ ] The reset link expires after 15 minutes and cannot be reused.
- [ ] The response is identical for known and unknown identifiers.
- [ ] Passwords below policy are rejected with a clear, bilingual message.
- [ ] The previous 24 passwords cannot be reused.
- [ ] A successful reset clears the UC-06 lockout.
- [ ] The reset is recorded in the core audit trail.

## Decisions to confirm with the client

1. **History depth.** 24 is the common regulated default. DNA may already hold a
   history that Auth0 cannot see, so for legacy users "no reuse" is only enforced
   from migration onwards. If the requirement is absolute, the core has to expose
   a "was this password used before" check and `change_password.js` must call it.
2. **MFA before reset.** Today the emailed link is the only factor. Requiring an
   enrolled factor as well is materially stronger and is a small change to the
   password-reset-post-challenge Action - worth raising with the fraud team.
