# UC-15 - Support-Initiated Customer Unblock

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** task 7.5
**Status:** implemented in code

## Scope

An agent restores access to an account that was locked, whether automatically by
UC-06 or deliberately by UC-14.

## Two locks, two clears

This is where confusing the two lock types costs the most time.

| Lock | Symptom | Clear with |
|---|---|---|
| Brute-force (UC-06) | `too_many_attempts` | `DELETE /api/v2/user-blocks/{id}` |
| Explicit (UC-14) | `user is blocked` | `PATCH /api/v2/users/{id}` with `blocked: false` |

An agent who clears only one will be told by the customer, a few minutes later,
that it still does not work. **The support portal should always do both** and
report which one was actually in effect.

## Flow

1. Agent verifies the caller and confirms the lock is safe to lift - for a UC-14
   lock, that means reading `blocked_reason` first.
2. The portal backend clears the explicit flag and the metadata, recording
   `unblocked_by` and `unblocked_at`.
3. It also clears any brute-force block.
4. The customer is notified.
5. If the lock followed suspected compromise, a password reset (UC-12) is
   triggered in the same interaction - restoring access to a possibly
   compromised credential is not a fix.

## Terraform and code

```
modules/b2c/actions/scripts/post-login/01-access-control.js   # reads app_metadata.blocked
stacks/b2c/main.tf                                            # unlock:customer scope
```

## Testing before the front end exists

Postman folder **UC-12, UC-14, UC-15** runs lock -> denied -> unblock -> clear
blocks -> login restored, then reads the `sapi` log entries to confirm the
Management API calls were recorded.

## Acceptance criteria

- [ ] Both lock types can be cleared from one agent action.
- [ ] `blocked_reason` is cleared alongside the flag - no stale reason.
- [ ] `unblocked_by` and `unblocked_at` are recorded.
- [ ] The customer can sign in immediately afterwards.
- [ ] The customer is notified.
- [ ] Only `unlock:customer` holders can unblock.
- [ ] Every unblock appears in the audit trail with the agent's identity.

## Decisions to confirm with the client

1. **Forced reset on unblock.** Recommend making it mandatory when
   `blocked_reason` indicates suspected compromise, and optional otherwise. That
   rule belongs in the support portal, driven by the reason vocabulary from UC-14.
2. **Repeat unblocks.** Three unblocks for the same customer in thirty days is a
   signal, not a coincidence. Worth a report for the fraud team.
