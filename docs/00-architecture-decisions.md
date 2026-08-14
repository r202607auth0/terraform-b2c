# Architecture decisions

The decisions that would be expensive to reverse, and why they went the way they
did. Each is a real fork with a real trade-off, not a formality.

---

## AD-01 - Shared tenant, separate connections

**Decision.** B2C shares the existing Auth0 tenant with B2B. Populations are
separated by connection (`OLB-B2C-DNA` versus the existing B2B connections),
clients and roles - not by tenant.

**Why.** A separate tenant would give the cleanest blast radius, but it doubles
tenant-level configuration (branding, email provider, attack protection, MFA
factors), doubles the operational surface, and makes any future shared experience
impossible. The programme already runs four environments; eight tenants is a
different kind of project.

**Cost.** Tenant singletons are now contended. Every Action guards on
`event.connection.name`, and trigger bindings are owned by exactly one stack
(AD-02). A B2C mistake can affect B2B logins - which is precisely why the
connection guard is the first line of every Action and is asserted in tests.

---

## AD-02 - Three stacks, bindings owned at the root

**Decision.** Three Terraform states: the existing B2B stack, `stacks/b2c`, and
`stacks/tenant` which owns every tenant singleton including all
`auth0_trigger_actions`.

**Why.** A trigger binding is a tenant singleton. If B2B and B2C each declared
`auth0_trigger_actions` for `post-login`, every apply would remove the other
side's Actions. That failure is intermittent, environment-specific, and presents
as "MFA randomly stopped working" - the worst kind to debug.

`stacks/b2c` therefore creates Actions and **outputs their ids**. `stacks/tenant`
reads that output through `terraform_remote_state` and composes the ordered list.

**Cost.** Apply order matters: `b2c` before `tenant`, enforced by
`max-parallel: 1` in the workflow matrix. A new B2C Action needs two applies.

**Order within post-login.** B2B first, then B2C, so an existing partner control
cannot be short-circuited by a B2C rule that returns early on a connection
mismatch.

---

## AD-03 - Auth0 owns credentials, DNA owns member data

**Decision.** After migration, Auth0 is the sole credential store. Fiserv DNA
remains authoritative for member and account data, reached only through VeriPark.

**Why.** Two credential stores means two lockout counters, two password policies
and two places for a reset to go wrong. The requirements already assume Auth0
behaviours - brute-force protection, password history, breached-password
detection - that a synchronised model would only partly deliver.

**Cost.** DNA no longer holds the password, so any legacy channel still
authenticating against it must be migrated or federated. This needs confirming
before cutover.

---

## AD-04 - Trickle migration via a custom database connection

**Decision.** `import_mode = true`. Users move on first successful login.

**Why.** A bulk export of password hashes needs Fiserv to release them in a
format Auth0 accepts, which is a commercial and technical negotiation of unknown
length. Trickle migration needs no export, no password reset campaign, and no
customer-visible event.

**Cost.** The legacy path stays live until the population drains, and every one
of those logins depends on APIM and VeriPark being up. `login.js` times out at
5 seconds, so a slow core is a failed login for a real customer. The p99 latency
target in the OpenAPI contract is not decoration.

**Exit.** Set `legacy_migration_enabled = false` when the tail is small enough,
reset the remainder, then set `import_mode = false`.

---

## AD-05 - MFA policy lives in the Action, not in Guardian

**Decision.** `auth0_guardian.policy = ""`. The post-login Action decides every
challenge.

**Why.** UC-02 risk rules, UC-04 step-up and UC-05 factor selection are one
decision. A tenant-wide Guardian policy would compete with the Action for it, and
the two would disagree at exactly the moments that matter.

**Cost.** More code to test. Mitigated by that code being one file with the
decision written as three named booleans.

---

## AD-06 - BFF for web, PKCE for mobile

**Decision.** The VeriChannel web app authenticates through a confidential
backend-for-frontend. The mobile app is a public client using PKCE.

**Why.** A browser cannot keep a secret. A BFF keeps tokens server-side, out of
reach of XSS, and gives one place to enforce step-up ACR checks. A mobile binary
cannot keep a secret either, and PKCE is the answer there.

**Cost.** VeriChannel must build the BFF. If it turns out VeriChannel is a SPA
with no server tier, that is a schedule risk worth surfacing now - the client
configuration would change from `regular_web` to `spa` and the security posture
with it.

---

## AD-07 - A test harness client with the password grant

**Decision.** Non-production environments get a client with the
`password-realm`, `mfa-oob` and `mfa-otp` grants. `stacks/b2c` refuses to create
it when `env == "prod"`, regardless of the tfvars.

**Why.** The front end, the Private APIM and the core are all unavailable. Without
a headless path, nothing can be tested until all three arrive, and the December
gate does not move. The resource-owner password grant is the only way to drive
login and MFA from Postman or CI.

**Cost.** The grant is genuinely dangerous - it defeats MFA-at-the-edge and
bypasses the browser entirely. Hence the code-level guard rather than a
configuration convention, and hence the `ZZ` name prefix so it sorts to the
bottom of the Dashboard where an auditor will spot it.

---

## AD-08 - The mock implements the contract, not the other way round

**Decision.** `mocks/openapi/private-apim-identity.yaml` is written first and is
the deliverable to the VeriPark and Fiserv teams. The mock implements it.

**Why.** The alternative is discovering at integration time that the core returns
a different shape, and rewriting the custom database scripts under deadline
pressure. Publishing the contract now turns an integration risk into a review
comment.

**Cost.** It only works if the vendors actually agree to it. Getting that
agreement is the highest-value thing on the critical path, and it is not a
technical task.
