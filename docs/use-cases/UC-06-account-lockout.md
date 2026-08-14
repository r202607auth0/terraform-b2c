# UC-06 - Account Lockout

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 5.6 - 5.8
**Status:** implemented in code

## Scope

Three consecutive failed password attempts lock the account. The customer is
emailed. The lock is lifted by a self-service password reset (UC-07) or by an
agent (UC-15).

## Two different locks

Confusing these two costs an afternoon every time.

| | Brute-force block | `blocked` flag |
|---|---|---|
| Set by | Auth0 attack protection, automatically | An agent or the fraud team (UC-14) |
| Scope | The identifier/IP pair | The user, everywhere |
| Cleared by | Successful SSPR, `DELETE /api/v2/user-blocks/{id}`, or 30 days | `PATCH /api/v2/users/{id}` with `blocked: false` |
| Visible as | `too_many_attempts` | `unauthorized`, `user is blocked` |

UC-06 is the first. UC-14 and UC-15 are the second.

## Configuration

```hcl
brute_force_protection {
  enabled      = true
  max_attempts = 3                                  # the requirement
  mode         = "count_per_identifier_and_ip"
  shields      = ["block", "user_notification"]     # Req-3: tell the customer
}
```

`count_per_identifier_and_ip` counts per pair, so an attacker rotating IPs is not
stopped by this control alone - `suspicious_ip_throttling` and breached-password
detection cover that, and both are enabled in the same module.

## MFA failure lockout

The requirement asks for a lock when the second factor is repeatedly wrong.
Auth0's brute-force counter covers the password, not the MFA challenge; MFA
attempts are separately rate-limited by the platform and are not configurable to
a 3-attempt hard lock.

**What is implemented:** repeated MFA failures are rate-limited by Auth0 and
logged (`gd_*` log codes). **What is not:** an automatic account lock on the
third MFA failure.

To close that gap, a log stream to the SIEM plus a rule that calls
`PATCH /api/v2/users/{id}` with `blocked: true` is the standard pattern, and it
also gives the fraud team a single place to tune the threshold. Flagged as an
open item below rather than quietly implemented, because it changes who owns the
lockout decision.

## Notification

`shields` includes `user_notification`, so Auth0 sends the `blocked_account`
template. It is bilingual, states plainly that a reset unlocks the account, and
links straight to the reset flow.

## Terraform and code

```
modules/tenant/attack_protection/main.tf
modules/tenant/experience/templates/blocked_account.html
environments/<env>/tenant.tfvars                # brute_force_max_attempts
```

## Testing before the front end exists

Postman folder **UC-06** fires three wrong passwords then a correct one and
asserts the correct one still fails. Add the CI runner's egress IP to
`brute_force_allowlist` only if the pipeline locks itself out - and then accept
that the folder no longer proves anything in CI.

The legacy path is also covered: `lockeduser` returns `423` from the mock, and the
test asserts that `ACCOUNT_LOCKED` never appears in the response to the caller.

## Acceptance criteria

- [ ] The account is locked after exactly 3 failed attempts.
- [ ] A correct password during the lock still fails.
- [ ] The customer receives the lockout email in their language.
- [ ] The response does not disclose whether the identifier exists.
- [ ] A successful SSPR clears the lock (UC-07).
- [ ] An agent can clear the lock (UC-15).

## Decisions to confirm with the client

1. **Three is aggressive.** Auth0's default is 10. Three will generate support
   calls, particularly from customers using password managers against the legacy
   username. Recommend 3 in staging to prove the control, then review the volume
   before it reaches production.
2. **MFA lockout ownership.** Confirm whether the SIEM-driven lock described above
   is in scope for Phase 3 or deferred.
