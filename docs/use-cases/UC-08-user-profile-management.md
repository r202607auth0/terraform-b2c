# UC-08 - User Profile Management

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 6.0 - 6.2
**Status:** implemented in code; the portal screens are VeriChannel's work

## Scope

The customer updates their own contact details and MFA preferences. Changes that
matter to fraud require a fresh step-up first, and all of them are audited.

## What the customer may change

| Field | Store | Step-up required |
|---|---|---|
| Email address | Auth0 primary + core | **Yes** (UC-04 action 1) |
| Phone number | Core, via VeriLink | Yes |
| Mailing address | Core only - Auth0 never holds it | Yes |
| Preferred language | `user_metadata.preferred_language` | No |
| Marketing preferences | `user_metadata` | No |
| MFA factor add/remove | Auth0 authenticators | **Yes** |

The dividing line: anything that could be used to take over the account, or that
changes where a notification lands, needs step-up.

## What the customer may never change

`app_metadata` - `cif`, `customer_type`, `member_id`, `dna_status`, `legacy`,
`blocked*`. Auth0 does not expose `app_metadata` to the user, and nothing in this
repo writes customer input into it after registration. The UC-08 Postman test
asserts the CIF is in `app_metadata` and absent from `user_metadata`, so a
regression fails a test rather than reaching production.

## Flow

1. Customer opens Profile in VeriChannel.
2. For a sensitive field, the BFF starts a fresh `/authorize` with `acr_values`
   and `obp_action=update_profile`.
3. The returned access token carries `.../acr = ...multi-factor`. **The API
   verifies that claim.** Requesting step-up is not receiving it.
4. The write goes to the core through the Private APIM. Auth0 is updated through
   the Management API only for the fields it owns.
5. A `PROFILE_UPDATED` security event is posted, and the customer is notified
   at the **old** address as well as the new one when the email changes.

## Terraform and code

```
modules/b2c/actions/scripts/post-login/03-adaptive-mfa.js   # step-up gate
stacks/b2c/main.tf                              # update:profile scope
mocks/dna-mock/server.js                        # /notifications/security-event
```

## Testing before the front end exists

Postman folder **UC-08 & UC-09** reads the profile, asserts the metadata split,
updates a non-sensitive preference, and confirms the write.

The step-up gate itself is exercised in UC-04 - there is no value in re-proving
it here, only in proving that the profile write happens once the token is right.

## Acceptance criteria

- [ ] Sensitive updates are refused without a step-up ACR on the token.
- [ ] The CIF and customer type cannot be altered by any customer-facing call.
- [ ] An email change notifies both the old and the new address.
- [ ] Every security-sensitive change is written to the audit trail with actor,
      timestamp, IP and user agent.
- [ ] Profile screens are bilingual and WCAG 2.1 AA.

## Decisions to confirm with the client

1. **Who owns the phone number.** If DNA is authoritative and Auth0 also holds it
   for MFA, they will drift. Recommend the core stays authoritative and Auth0
   holds only the MFA-enrolled number, synchronised one way.
2. **Cooling-off on email change.** Some institutions block money movement for 24
   hours after an email change. That rule belongs in the payment orchestration
   layer, but the signal comes from here - it needs a decision now so the event
   carries what the rule needs.
