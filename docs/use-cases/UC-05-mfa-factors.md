# UC-05 - MFA Factors

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 5.3 - 5.5
**Status:** Email OTP and TOTP implemented; Push deferred to Phase 2

## Factor inventory

| Factor | Type | AAL | Strength | Phase | State |
|---|---|---|---|---|---|
| Email OTP | Out-of-band | AAL2 | Low | 1 | Enabled |
| TOTP (authenticator app) | In-band, time-bound | AAL2 | Medium | 1 | Enabled |
| Push (Guardian SDK) | Out-of-band | AAL2+ | High | 2 | Configured, disabled |
| Recovery code | Backup | - | - | 1 | Enabled |
| ~~SMS OTP~~ | - | - | - | - | **Excluded by requirement** |

SMS is deliberately absent from `modules/tenant/mfa/main.tf`. It was struck from
the factor table, and the module comment says so, so nobody re-enables it by
reflex during an incident.

## Enrolment rules

- **Email OTP** requires a verified email. For a registered user that is
  satisfied by UC-01; for a legacy user by UC-03. This ordering is why email
  collection sits before the MFA Action in the post-login chain.
- **TOTP** may be enrolled at registration, or after two lower-strength factors
  are already in place. The secret is held by the authenticator app, never by
  Auth0's UI.
- **Push** enrols at registration for low-risk accounts. It stays off until the
  Guardian SDK is embedded in the VeriChannel mobile app - flipping
  `enable_push_mfa` before that would advertise a factor nobody can complete.

## Where the policy lives

`auth0_guardian.policy` is intentionally **empty**. A tenant-wide policy would
compete with the post-login Action for the same decision, and the Action is where
UC-02 risk rules and UC-04 step-up already live. One decision point, one place to
debug.

## Terraform and code

```
modules/tenant/mfa/main.tf                      # factor enablement
modules/b2c/actions/scripts/post-login/03-adaptive-mfa.js   # when to challenge
modules/tenant/experience/templates/mfa_oob_code.html       # the OTP email
```

## Testing before the front end exists

Postman folder **UC-04 & UC-05** drives the full MFA API:

```
POST /oauth/token   (password-realm)   -> 403 mfa_required + mfa_token
GET  /mfa/authenticators               -> what is enrolled
POST /mfa/associate                    -> enrol oob/email or otp
POST /mfa/challenge                    -> send the code
POST /oauth/token   (mfa-oob | mfa-otp) -> tokens
```

This is the strongest argument for the test harness client: the MFA API is the
only way to exercise enrolment and challenge without a browser, and it needs the
`mfa-oob` and `mfa-otp` grants.

Set `always_on_mfa = true` in `environments/dev/b2c.tfvars` before running the
folder, or a low-risk login is never challenged and there is no `mfa_token`.

Reading the code: in dev, take it from the Auth0 log stream or the mailbox and
paste it into the `email_otp_code` environment variable. For unattended CI, point
the tenant's email provider at a Mailosaur or MailSlurp inbox and fetch it in a
pre-request script.

## Acceptance criteria

- [ ] Email OTP can be enrolled only against a verified address.
- [ ] TOTP enrolment returns a barcode URI that a standard authenticator accepts.
- [ ] A successful challenge produces `acr = ...multi-factor` and a matching `amr`.
- [ ] Recovery codes are issued once, at first enrolment.
- [ ] SMS is not offered anywhere in the enrolment UI.
- [ ] Enrolment and challenge screens are bilingual and WCAG 2.1 AA.

## Decisions to confirm with the client

1. **Minimum factor count.** One factor at registration, or Email OTP plus TOTP?
   Two raises assurance and support call volume together.
2. **Push provider.** `guardian` (Auth0's own) or `sns` against the existing
   estate. The choice affects the mobile SDK integration, so it is worth settling
   before Phase 2 begins rather than during it.
