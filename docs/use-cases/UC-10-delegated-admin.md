# UC-10 - Delegated Admin Management

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 6.5 - 6.6
**Status:** partially implemented; the expiry sweep is an open item

## Scope

A business user grants another person scoped, time-bound access to their
accounts, and can modify or revoke it. This is the B2B-flavoured use case inside
the B2C programme, and it is the sixth high-risk action in UC-04.

## Model

| Concern | Mechanism |
|---|---|
| Who may delegate | `olb_delegated_admin` role |
| What a delegate receives | `olb_delegate` role - read-only scopes |
| Which accounts | `app_metadata.delegation.accounts[]` on the delegate |
| For how long | `app_metadata.delegation.expiresAt` |
| Granted by whom | `app_metadata.delegation.grantedBy` |

**Auth0 roles have no expiry.** That is the single most important thing to
remember here. The window lives in `app_metadata` and something has to enforce
it. Two options:

1. **Post-login check.** The Action drops the delegate role from the token when
   `expiresAt` has passed. Simple, immediate, but the role assignment lingers in
   Auth0 and looks live to anyone reading the Dashboard.
2. **Scheduled sweep.** A job calls the Management API and removes expired
   assignments. Auth0 state matches reality, at the cost of a job to run and
   monitor.

**Recommended: both.** The post-login check is the enforcement; the sweep is the
hygiene. Currently neither is written - the metadata contract is in place and the
Postman folder exercises grant, record, verify and revoke. This is the largest
open gap in the build and it is called out rather than buried.

## Flow

1. Delegator authenticates and requests a delegation. `obp_action=manage_delegates`
   triggers step-up (UC-04).
2. The portal creates or looks up the delegate's identity.
3. `POST /api/v2/users/{delegate}/roles` assigns `olb_delegate`.
4. `PATCH /api/v2/users/{delegate}` records accounts, scopes, `grantedBy` and
   `expiresAt`.
5. Both parties are notified.
6. Revocation removes the role and clears the metadata, and is itself notified.

## Terraform and code

```
stacks/b2c/main.tf      # olb_delegate, olb_delegated_admin roles and their scopes
```

## Testing before the front end exists

Postman folder **UC-10 & UC-11**: grant the role, record the window, confirm the
roles claim appears in the token, revoke.

`role_delegated_admin_id` comes from `make output ENV=dev STACK=b2c`.

## Acceptance criteria

- [ ] Only `olb_delegated_admin` holders can create a delegation.
- [ ] Creating one requires a fresh step-up.
- [ ] A delegate's token carries strictly fewer scopes than the delegator's.
- [ ] An expired delegation grants nothing, with no manual intervention.
- [ ] Revocation takes effect on the next token issuance at the latest.
- [ ] Every grant, change and revocation is attributable and notified.

## Decisions to confirm with the client

1. **Expiry enforcement.** Which of the two mechanisms above, or both. This needs
   settling before the December governance gate - it is a control, not a detail.
2. **Delegate identity.** Does a delegate need their own OLB registration
   (UC-01), or can they be invited? Invitation is friendlier and introduces an
   identity that was never CIF-validated. Recommend requiring registration.
3. **Maximum window.** An open-ended delegation is a standing risk. A 12-month
   cap with explicit renewal is the usual control.
