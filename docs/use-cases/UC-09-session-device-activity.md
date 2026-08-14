# UC-09 - User Session and Device Activity

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 6.3 - 6.4
**Status:** implemented in code; the display is VeriChannel's work

## Scope

The customer sees where and when their account has been used, and can end
sessions they do not recognise.

## Login history

Source: `GET /api/v2/logs?q=user_id:"<id>"&sort=date:-1`.

The Management API is rate-limited and is not a reporting database. Two rules:

1. **Never call it from the browser.** The BFF calls it with the `read:logs`
   scope and returns a trimmed projection.
2. **Cache it.** 60 seconds is enough to survive a customer refreshing the page.

Show only the codes a customer can act on:

| Code | Meaning |
|---|---|
| `s` | Successful login |
| `f` | Failed login |
| `ssa` | Successful silent authentication |
| `fp` | Failed password |
| `limit_wc` | Blocked by brute-force protection |
| `gd_auth_succeed` / `gd_auth_failed` | MFA succeeded / failed |

For retention beyond Auth0's window - and any regulated retention requirement
will be beyond it - configure a log stream to the SIEM or to Azure Event Hubs. A
`log_streams` module is a small addition to `stacks/tenant` once the destination
is chosen.

## Active sessions

| Operation | Endpoint |
|---|---|
| List | `GET /api/v2/users/{id}/sessions` |
| Revoke one | `DELETE /api/v2/sessions/{session_id}` |
| Revoke all | `DELETE /api/v2/users/{id}/sessions` |

Revoking a session does not revoke refresh tokens. To force a genuine
logout-everywhere, also `DELETE /api/v2/users/{id}/refresh-tokens`. Doing only
the first is a common and quiet failure.

## Terraform and code

```
stacks/b2c/main.tf      # read:sessions, revoke:sessions, read:login_history scopes
                        # and the Management API grants on support_m2m
```

## Testing before the front end exists

Postman folder **UC-08 & UC-09** reads the log for a known user, asserts that IP
and user agent are captured, lists sessions and revokes them.

## Acceptance criteria

- [ ] The customer sees date, time, approximate location, device and outcome for
      recent logins.
- [ ] Active sessions can be listed and individually revoked.
- [ ] Revoke-all ends every session **and** every refresh token.
- [ ] A revoked session cannot refresh a token.
- [ ] The customer's own history is never reachable with another customer's token.

## Decisions to confirm with the client

1. **Retention.** Auth0's log retention depends on the subscription tier and will
   almost certainly be shorter than the regulatory requirement. A log stream is
   not optional - only the destination is open.
2. **Location granularity.** City-level is useful and slightly identifying.
   Country-level is safer. Pick one and apply it consistently.
