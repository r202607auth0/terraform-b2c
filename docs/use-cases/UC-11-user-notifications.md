# UC-11 - User Notifications

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** task 6.7
**Status:** implemented in code

## Scope

The customer is told when something security-relevant happens to their account.

## Event catalogue

| Event | Raised by | Channel |
|---|---|---|
| `ACCOUNT_LOCKED` | Auth0 attack protection, `user_notification` shield | Email (`blocked_account`) |
| `PASSWORD_CHANGED` | post-change-password Action | Core notification service |
| `PASSWORD_RESET_COMPLETED` | password-reset-post-challenge Action | Core notification service |
| `STEP_UP_REQUESTED` | adaptive-MFA Action | Core notification service |
| `PROFILE_UPDATED` | VeriLink, after a UC-08 write | Core notification service |
| `NEW_DEVICE_LOGIN` | post-login Action, on a NewDevice risk signal | Core notification service |
| Email verification | Auth0 | Email (`verify_email`) |
| MFA code | Auth0 | Email (`mfa_oob_code`) |

## The split, and why

Two senders, deliberately:

- **Auth0** sends anything tied to a token or a link it alone can mint -
  verification, reset, MFA codes, lockout. These cannot be delegated without
  handing out the token.
- **The core** sends everything else, through `POST /notifications/security-event`.
  That keeps one customer-communication log across all channels, honours the
  customer's contact preferences, and means marketing suppression rules apply
  where they should.

Every core-bound notification is **best-effort**. Each Action wraps the call in
try/catch with a 3-second timeout and logs on failure. A notification service
outage must never fail a login - that trade is deliberate and worth stating
plainly to the fraud team.

## Terraform and code

```
modules/b2c/actions/scripts/post-login/03-adaptive-mfa.js
modules/b2c/actions/scripts/password-reset-post-challenge/unlock-and-notify.js
modules/b2c/actions/scripts/post-change-password/notify.js
modules/tenant/experience/templates/*.html
modules/tenant/attack_protection/main.tf        # user_notification shield
```

## Testing before the front end exists

The mock records every event. `GET {mock_base_url}/_admin/events?kind=security-event`
returns the ledger, and the Postman folder asserts that each event names a
customer by `cif` or `auth0UserId` - an unattributable security notification is
not much of a control.

## Acceptance criteria

- [ ] Every event in the catalogue is emitted when its condition occurs.
- [ ] Each carries the customer identifier, timestamp, IP and user agent.
- [ ] Emails render in the customer's language.
- [ ] A notification failure never fails the underlying authentication.
- [ ] No notification contains a credential, a full account number or a code
      alongside the link it protects.

## Decisions to confirm with the client

1. **Push notifications.** The catalogue is email-only today. Push needs the
   mobile SDK, which is the same Phase-2 dependency as UC-05 push MFA.
2. **Rate limiting.** A customer failing MFA repeatedly could receive a burst of
   emails. The core notification service should collapse duplicates within a
   short window - it is better placed to do that than Auth0.
