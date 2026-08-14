# Traceability matrix

Every task in the project plan, mapped to the code that implements it and the
test that proves it. Two rows are marked as gaps; they are also carried in the
open-items table in the README.

| Task | Activity | Use case | Implementation | Test |
|---|---|---|---|---|
| 3.0 | Tenant/env Terraform, 4 envs | Foundation | `stacks/`, `environments/` | `make validate` |
| 3.1 | Applications | Foundation | `modules/b2c/clients` | UC-02 login |
| 3.2 | APIs / resource servers | Foundation | `modules/b2c/apis` | token `aud` assertion |
| 3.3 | Connections | Foundation | `modules/b2c/connection_dna` | UC-01, UC-03 |
| 3.4 | RBAC roles and permissions | Foundation | `modules/b2c/rbac` | UC-10 roles claim |
| 3.5 | MFA policy - Email OTP, TOTP | UC-05 | `modules/tenant/mfa` | UC-05 associate/challenge |
| 3.6 | Actions skeleton | Foundation | `modules/b2c/actions` | `node --check` in CI |
| 3.7 | CI/CD with approval gates | Foundation | `.github/workflows/b2c-terraform.yml` | pipeline run |
| 3.8 | Drift detection | Foundation | `.github/workflows/b2c-drift.yml` | `make drift` |
| 3.9 | Dev smoke test | Foundation | `postman/` folder 00 | Setup folder |
| 4.0 | Custom signup prompt captures CIF | UC-01 | `prompt-signup-*.json` | UC-01 signup |
| 4.1 | Pre-user-reg CIF validation, bank vs trust | UC-01 | `pre-user-registration/cif-validation.js` | UC-01 all 5 requests |
| 4.2 | Email activation, first password, complexity | UC-01 | `verify_email.html`, `connection_dna/main.tf` | UC-01, UC-07 weak-password |
| 4.3 | Mandatory MFA enrolment at registration | UC-01 / UC-05 | `03-adaptive-mfa.js`, `tenant/mfa` | UC-05 associate |
| 4.4 | Identity verification, WCAG 2.1AA, EN/FR | UC-01 | `cif-validation.js`, `prompt-*-fr-CA.json` | manual a11y audit |
| 4.5 | Standard login | UC-02 | `modules/b2c/connection_dna` | UC-02 login succeeds |
| 4.6 | IP / geo block | UC-02 | `01-access-control.js` | UC-02 geo block |
| 4.7 | Risk-based MFA challenge | UC-02 | `03-adaptive-mfa.js` | UC-05 mfa_required |
| 4.8 | Adaptive MFA + email verification | UC-02 | `03-adaptive-mfa.js`, `01-access-control.js` | UC-02 unverified denied |
| 4.9 | Session timeout, rate limiting | UC-02 | `clients/main.tf`, `tenant/attack_protection` | UC-06 |
| 4.10 | Legacy login, email-on-file check | UC-03 | `login.js`, `02-legacy-email-collection.js` | UC-03 legacy login |
| 4.11 | Email collection, in-use check, OTP | UC-03 | `02-legacy-email-collection.js`, mock form | UC-03 BROWSER STEP |
| 4.12 | MFA enrolment after email update | UC-03 / UC-05 | `03-adaptive-mfa.js` | UC-05 |
| 4.13 | UC-01/02/03 test execution | Testing | `postman/` | folders UC-01..03 |
| 5.0 | Step-up option 1 - always challenge | UC-04 | `03-adaptive-mfa.js` | UC-04 BROWSER STEP |
| 5.1 | Step-up option 2 - conditional | UC-04 | `03-adaptive-mfa.js` (`alreadyMfad`) | UC-04 |
| 5.2 | Step-up for all 6 high-risk actions | UC-04 | `HIGH_RISK_ACTIONS`, OLB API scopes | UC-04 + security-event |
| 5.3 | Email OTP factor | UC-05 | `tenant/mfa`, `mfa_oob_code.html` | UC-05 associate oob |
| 5.4 | TOTP factor | UC-05 | `tenant/mfa` | UC-05 associate otp |
| 5.5 | Push / Guardian SDK | UC-05 | `tenant/mfa` (`enable_push`) | deferred to Phase 2 |
| 5.6 | Brute-force lockout, 3 attempts | UC-06 | `tenant/attack_protection` | UC-06 folder |
| 5.7 | MFA-failure lockout | UC-06 | **gap - see UC-06 doc** | not covered |
| 5.8 | Lockout email notification | UC-06 | `blocked_account.html`, `user_notification` shield | manual inbox check |
| 5.9 | SSPR flow, 15-min link | UC-07 | `experience/main.tf` (900s) | UC-07 folder |
| 5.10 | Complexity + history / no reuse | UC-07 | `connection_dna/main.tf` | UC-07 weak password |
| 5.11 | Self-service unlock via SSPR | UC-07 | `unlock-and-notify.js` | UC-07 security-event |
| 5.12 | UC-04/05/06/07 test execution | Testing | `postman/` | folders UC-04..07 |
| 6.0 | Contact detail and MFA preference updates | UC-08 | Management API + `update:profile` | UC-08 folder |
| 6.1 | Step-up before sensitive updates | UC-08 | `03-adaptive-mfa.js` | UC-04 |
| 6.2 | Audit logging for profile actions | UC-08 | `/notifications/security-event` | UC-11 ledger |
| 6.3 | Login history display | UC-09 | `read:logs` grant | UC-09 logs query |
| 6.4 | Session list / revoke / force logout | UC-09 | `delete:sessions` grant | UC-09 sessions |
| 6.5 | Delegate create / modify / revoke | UC-10 | `rbac` roles | UC-10 folder |
| 6.6 | Role-scoped, time-bound delegation + audit | UC-10 | **partial - expiry sweep is a gap** | UC-10 partial |
| 6.7 | Event-driven notifications | UC-11 | all four notify paths | UC-11 ledger |
| 6.8 | UC-08/09/10/11 test execution | Testing | `postman/` | folders UC-08..11 |
| 7.0 | Support-initiated reset, functional | UC-12 | `support_agent` role | UC-12 folder |
| 7.1 | Support reset via Management API + audit | UC-12 | `create:user_tickets` grant | UC-12 ticket |
| 7.4 | Support-initiated lockout | UC-14 | `01-access-control.js`, `lock:customer` | UC-14 folder |
| 7.5 | Support-initiated unblock | UC-15 | `unlock:customer`, user-blocks | UC-15 folder |
| 7.6 | UC-12/14/15 test execution | Testing | `postman/` | folder UC-12/14/15 |

## Coverage summary

| | Count |
|---|---|
| Plan tasks | 51 |
| Implemented in code | 49 |
| Gaps | 2 (5.7 MFA-failure lockout, 6.6 delegation expiry) |
| Postman requests | 55 across 10 folders |
| Requiring a browser | 3 (UC-03 redirect, UC-04 step-up, UC-05 interactive enrolment) |

## Non-functional requirements

| Requirement | Where it is met | How it is verified |
|---|---|---|
| WCAG 2.1 AA | Universal Login new experience + prompt custom text; mock form uses semantic HTML, labelled inputs, 4.5:1 contrast | Manual audit with axe - **not automated** |
| English + Canadian French | `enabled_locales`, `prompt_custom_text` per language, bilingual email templates, `MESSAGES` maps in every Action | Locale assertion in UC-03; visual check per screen |
| Password 12+ with four classes | `password_policy = "excellent"` + `min_length = 12` | UC-07 weak-password request |
| No password reuse | `password_history { size = 24 }` | Manual - needs 25 resets |
| Reset link expires in 15 min | `url_lifetime_in_seconds = 900`, `ttl_sec: 900` | UC-07, UC-12 |
| No PII to an unauthorised caller | Identical responses for known and unknown identifiers | UC-07 paired requests |
| Audit trail | Auth0 tenant logs + `/notifications/security-event` | UC-11 ledger, `sapi` log query |
| Blocked geographies | KP, IR, RU, MM, SY, CU + UA-43 | UC-02 - verify in a browser |

## Where the gaps are

**5.7 - MFA-failure lockout.** Auth0's brute-force counter applies to password
attempts, not MFA challenges. MFA failures are platform-rate-limited and logged
(`gd_*` codes) but do not trigger an account lock at a configurable threshold.
Closing this needs a log stream plus a SIEM rule calling
`PATCH /api/v2/users/{id}` with `blocked: true`. That moves the lockout decision
outside Auth0, which is a design choice the fraud team should make rather than
one to make for them.

**6.6 - Delegation expiry.** Auth0 roles have no expiry. `app_metadata.delegation.expiresAt`
is written and the Postman folder exercises grant and revoke, but nothing enforces
the window yet. Recommended: a post-login check that drops the role from the token
when expired, plus a scheduled sweep that removes the assignment. See
[UC-10](use-cases/UC-10-delegated-admin.md).
