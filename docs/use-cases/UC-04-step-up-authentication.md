# UC-04 - Step-Up Authentication

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 5.0 - 5.2
**Status:** implemented in code

## Scope

Six actions identified by the Fraud Team require a fresh authentication
regardless of how the session began:

1. Update profile, including email address
2. Add or manage e-Transfer recipients
3. Create or edit the Interac profile
4. Add or manage bill payees
5. CRA direct deposit registration
6. Add or manage delegates (B2B context, see UC-10)

## The two options in the plan

**Option 1 - always challenge.** Every high-risk action prompts, even if MFA was
completed minutes ago. Highest assurance, most friction.

**Option 2 - conditional.** Challenge only when MFA has not already been
satisfied in this session.

Both are implemented in one Action. `acr_values` selects between them: the
presence of a step-up ACR forces the challenge (Option 1 behaviour) by disabling
browser remembering; without it, a session that already carries an MFA method in
`event.authentication.methods` is not re-challenged (Option 2).

**Recommendation:** Option 1 for money movement (2, 3, 4, 5), Option 2 for
profile changes (1) and delegate management (6). This is a one-line change per
action in VeriChannel - whether it sends the ACR - not a code change here.

## How VeriChannel requests step-up

```
GET https://{domain}/authorize
  ?response_type=code
  &client_id=<olb_web>
  &redirect_uri=<bff callback>
  &scope=openid manage:bill_payees
  &audience=https://api.obp.ca/olb
  &acr_values=http://schemas.openid.net/pape/policies/2007/06/multi-factor
  &prompt=login
  &obp_action=manage_bill_payees
```

- `acr_values` triggers the challenge. `urn:obp:acr:stepup` is accepted as a
  tenant-local synonym.
- `prompt=login` prevents silent SSO from satisfying the request.
- `obp_action` names which of the six actions is being attempted, so it reaches
  the audit trail and the customer notification.

The resulting token carries `.../acr = ...multi-factor` and an `amr` naming the
factor. **The API must verify the ACR claim before performing the action** -
requesting step-up is not the same as having received it.

## Terraform and code

```
modules/b2c/actions/scripts/post-login/03-adaptive-mfa.js
stacks/b2c/main.tf                              # high-risk scopes on the OLB API
```

## Logging and notification

Every step-up request writes:

- an Auth0 log entry through `console.log` in the Action, carrying user, action, IP;
- `app_metadata.last_stepup_action`;
- a `STEP_UP_REQUESTED` security event to `POST /notifications/security-event`,
  best-effort - a notification failure must never block the transaction.

## Testing before the front end exists

Step-up is inherently interactive. Postman folder **UC-04 & UC-05** carries the
`/authorize` URL as a BROWSER STEP, plus an assertion against
`GET {mock_base_url}/_admin/events?kind=security-event` that the
`STEP_UP_REQUESTED` event was emitted.

For an automated regression, drive the same URL with Playwright once VeriChannel's
login page is stable.

## Acceptance criteria

- [ ] Each of the six actions prompts for a factor when the ACR is requested.
- [ ] The issued token's `acr` claim changes only after a real second factor.
- [ ] Browser remembering does not suppress a step-up challenge.
- [ ] Every attempt, successful or not, appears in the Auth0 log with the action name.
- [ ] The customer is notified that a step-up was attempted.
- [ ] The resource server rejects a high-risk call whose token lacks the ACR.

## Decisions to confirm with the client

1. **Step-up validity window.** Does one step-up cover a batch of payees, or does
   each one prompt? A 5-minute window is the usual compromise; it needs a
   timestamp check in the API, not in Auth0.
2. **Factor for step-up.** Currently any enrolled factor satisfies it. The fraud
   team may want to require the strongest enrolled factor for money movement, which
   means `challengeWith` on a specific type rather than `enable('any')`.
