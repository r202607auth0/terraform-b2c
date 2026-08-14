/**
 * UC-06 / UC-07 - Completing a self-service password reset lifts the lockout.
 *
 * Auth0 clears its own brute-force block on a successful reset. What this
 * Action adds is the notification and the core-side audit record, so that the
 * "account unlocked" step in the functional flow is evidenced outside Auth0.
 *
 * Secrets: APIM_BASE_URL, APIM_API_KEY, B2C_CONNECTION_NAME
 */

exports.onExecutePostChallenge = async (event, api) => {
  if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) return;

  const app = event.user.app_metadata || {};

  try {
    await fetch(`${event.secrets.APIM_BASE_URL}/notifications/security-event`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': event.secrets.APIM_API_KEY
      },
      body: JSON.stringify({
        type: 'PASSWORD_RESET_COMPLETED',
        cif: app.cif,
        auth0UserId: event.user.user_id,
        metadata: {
          ip: event.request.ip,
          unlocked: true,
          at: new Date().toISOString()
        }
      }),
      signal: AbortSignal.timeout(3000)
    });
  } catch (err) {
    console.log(`sspr: notification failed: ${err.message}`);
  }
};
