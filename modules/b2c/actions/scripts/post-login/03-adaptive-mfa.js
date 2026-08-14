/**
 * UC-02 Req-4 (adaptive MFA), UC-04 (step-up), UC-05 (factor selection).
 *
 * Three ways this Action decides to challenge:
 *   1. ALWAYS_ON_MFA = true            -> challenge every login.
 *   2. acr_values requests step-up     -> challenge, browser memory disabled.
 *   3. Auth0 risk assessment is not    -> challenge.
 *      "low" on NewDevice /
 *      ImpossibleTravel / UntrustedIP
 *
 * High-risk actions (UC-04) ask for step-up by starting a fresh /authorize with
 *   acr_values=http://schemas.openid.net/pape/policies/2007/06/multi-factor
 * or the tenant-specific urn:obp:acr:stepup, plus prompt=login.
 *
 * Secrets: ALWAYS_ON_MFA, B2C_CONNECTION_NAME, APIM_BASE_URL, APIM_API_KEY
 */

const STEPUP_ACRS = [
  'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
  'urn:obp:acr:stepup'
];

const HIGH_RISK_ACTIONS = [
  'update_profile',
  'manage_etransfer_recipients',
  'manage_interac_profile',
  'manage_bill_payees',
  'cra_direct_deposit',
  'manage_delegates'
];

const requestedAcrs = (event) => {
  const fromTransaction = (event.transaction && event.transaction.acr_values) || [];
  const fromQuery = String((event.request.query || {}).acr_values || '').split(' ').filter(Boolean);
  return [...fromTransaction, ...fromQuery];
};

const riskTriggered = (event) => {
  const ra = event.authentication && event.authentication.riskAssessment;
  if (!ra) return false;
  if (ra.confidence === 'low' || ra.confidence === 'medium') return true;

  const a = ra.assessments || {};
  const flagged = (x) => x && x.code && x.code !== 'not_found' && x.confidence !== 'high';
  return flagged(a.NewDevice) || flagged(a.ImpossibleTravel) || flagged(a.UntrustedIP);
};

const alreadyMfad = (event) =>
  (event.authentication && event.authentication.methods || []).some(
    (m) => m.name === 'mfa' || m.name === 'otp' || m.name === 'email'
  );

exports.onExecutePostLogin = async (event, api) => {
  if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) return;

  const acrs = requestedAcrs(event);
  const stepUp = acrs.some((a) => STEPUP_ACRS.includes(a));
  const alwaysOn = event.secrets.ALWAYS_ON_MFA === 'true';
  const risky = riskTriggered(event);

  // The high-risk action name is passed through so it lands in the audit trail.
  const highRiskAction = String((event.request.query || {}).obp_action || '');
  if (highRiskAction && !HIGH_RISK_ACTIONS.includes(highRiskAction)) {
    console.log(`adaptive-mfa: unknown obp_action "${highRiskAction}" ignored`);
  }

  if (!alwaysOn && !stepUp && !risky) return;

  // UC-04 Option 2: if MFA already happened in this session and this is not an
  // explicit step-up request, do not challenge a second time.
  if (!stepUp && alreadyMfad(event)) return;

  console.log(
    `adaptive-mfa: challenge user=${event.user.user_id} stepUp=${stepUp} alwaysOn=${alwaysOn} risky=${risky} action=${highRiskAction || 'n/a'}`
  );

  api.multifactor.enable('any', { allowRememberBrowser: !stepUp });

  api.user.setAppMetadata('last_mfa_challenge_at', new Date().toISOString());
  if (stepUp) {
    api.user.setAppMetadata('last_stepup_action', highRiskAction || 'unspecified');
  }

  // UC-04 / UC-11: the customer is told that a step-up was attempted.
  if (stepUp) {
    try {
      await fetch(`${event.secrets.APIM_BASE_URL}/notifications/security-event`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': event.secrets.APIM_API_KEY
        },
        body: JSON.stringify({
          type: 'STEP_UP_REQUESTED',
          cif: (event.user.app_metadata || {}).cif,
          auth0UserId: event.user.user_id,
          metadata: {
            action: highRiskAction || 'unspecified',
            ip: event.request.ip,
            userAgent: event.request.user_agent
          }
        }),
        signal: AbortSignal.timeout(3000)
      });
    } catch (err) {
      // Notification is best-effort; it must never block the login.
      console.log(`adaptive-mfa: notification failed: ${err.message}`);
    }
  }
};
