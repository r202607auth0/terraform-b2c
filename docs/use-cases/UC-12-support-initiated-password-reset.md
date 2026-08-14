# UC-12 - Support-Initiated Password Reset

> Part of the OBP B2C identity build. See [`../../README.md`](../../README.md) for the
> deployment guide and [`../03-traceability-matrix.md`](../03-traceability-matrix.md)
> for the requirement-to-code mapping.


**Plan reference:** tasks 7.0 - 7.1
**Status:** implemented in code

## Scope

A contact-centre agent, having verified the caller by the usual script, triggers
a password reset. The agent never sees, sets or transmits a password.

## Flow

1. Agent authenticates to the support portal and verifies the caller's identity
   out of band.
2. Agent searches for the customer. The result shows status and last activity -
   never a credential.
3. Agent selects **Send password reset**.
4. The portal backend calls `POST /api/v2/tickets/password-change` with
   `ttl_sec: 900` and `mark_email_as_verified: false`.
5. Auth0 emails the link to the address **on file**. The agent cannot redirect it.
6. The customer completes UC-07.
7. Agent action and customer completion are both audited.

## Why a ticket rather than a temporary password

A temporary password has to be spoken aloud, which puts a working credential in
the call recording and in the agent's short-term memory. The ticket goes only to
the address on file, so an attacker who has socially engineered the agent still
cannot receive it.

`mark_email_as_verified: false` matters: a reset must not be a route to verifying
an address that was never proven.

## Scope model

`support_m2m` holds `create:user_tickets`, `read:users` and `update:users` and is
never exposed to a browser. The agent's own token carries `initiate:password_reset`
on the Support API, and the portal backend checks it before calling Auth0. Two
gates: the agent must be entitled, and only the backend may reach Auth0.

## Terraform and code

```
stacks/b2c/main.tf      # support_agent role, support_m2m grants, Support API scopes
```

## Testing before the front end exists

Postman folder **UC-12, UC-14, UC-15** mints a Management API token with the
`support_m2m` credentials and creates a ticket, asserting the URL comes back and
the TTL was honoured.

## Acceptance criteria

- [ ] The agent can trigger a reset without seeing any credential.
- [ ] The link goes only to the address on file.
- [ ] It expires in 15 minutes and is single use.
- [ ] `mark_email_as_verified` is false.
- [ ] The action is attributable to a named agent in the audit trail.
- [ ] An agent without `initiate:password_reset` is refused.

## Decisions to confirm with the client

1. **Caller verification.** Auth0 cannot enforce the identity check that happens
   before step 3. It belongs in the support portal and in the agent script, and
   it is the weakest link in this use case.
2. **Agent MFA.** The support portal client should require step-up for any
   customer-affecting action. Worth making explicit rather than assuming.
