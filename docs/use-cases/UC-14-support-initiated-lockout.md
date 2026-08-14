# UC-14 - Support-Initiated Customer Lockout

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** task 7.4
**Status:** implemented in code

## Scope

An agent or fraud analyst locks a customer account immediately - suspected
takeover, a customer reporting a lost device, or a fraud rule firing.

## Flow

1. Agent verifies the caller, or the fraud team acts on a case.
2. The portal backend calls:

```http
PATCH /api/v2/users/{id}
{
  "blocked": true,
  "app_metadata": {
    "blocked": true,
    "blocked_reason": "SUPPORT_INITIATED",
    "blocked_by": "agent-0042",
    "blocked_at": "2026-08-13T14:00:00Z"
  }
}
```

3. Existing sessions are ended: `DELETE /api/v2/users/{id}/sessions` **and**
   `DELETE /api/v2/users/{id}/refresh-tokens`. Setting `blocked` alone stops the
   next login but leaves a live session working.
4. The customer is notified through the core.
5. Both the Auth0 flag and the metadata are set.

## Why both the flag and the metadata

The `blocked` flag is what Auth0 enforces. The metadata is what the next person
reads. Without `blocked_by` and `blocked_at`, the next agent sees a locked
account with no idea who locked it or why, and the auditor sees the same.

The post-login access-control Action also checks `app_metadata.blocked`, so a
lock is enforced twice - once by the platform, once by our own code. If someone
clears the flag in the Dashboard without clearing the metadata, the account stays
locked. That asymmetry is intentional: it fails safe.

## Terraform and code

```
modules/b2c/actions/scripts/post-login/01-access-control.js
stacks/b2c/main.tf      # lock:customer scope, fraud_analyst role
```

## Testing before the front end exists

Postman folder **UC-12, UC-14, UC-15** locks the account, asserts the reason is
attributable, then attempts a login and asserts it fails.

## Acceptance criteria

- [ ] The lock takes effect immediately for new logins.
- [ ] Existing sessions and refresh tokens are ended.
- [ ] The reason, actor and timestamp are recorded.
- [ ] The customer is notified.
- [ ] Only `lock:customer` holders can lock an account.
- [ ] The lock survives a Dashboard flag change without matching metadata.

## Decisions to confirm with the client

1. **Reason codes.** `SUPPORT_INITIATED` is a placeholder. The fraud team should
   supply a controlled vocabulary - suspected takeover, customer request,
   deceased, legal hold - because it drives what the customer is told.
2. **Four-eyes.** Should a lock need a second approver? For fraud-initiated locks
   the delay is usually unacceptable; for legal holds it usually is not.
