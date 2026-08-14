/**
 * UC-11 - Credential change notification.
 *
 * Secrets: APIM_BASE_URL, APIM_API_KEY
 */

exports.onExecutePostChangePassword = async (event, api) => {
  try {
    await fetch(`${event.secrets.APIM_BASE_URL}/notifications/security-event`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': event.secrets.APIM_API_KEY
      },
      body: JSON.stringify({
        type: 'PASSWORD_CHANGED',
        auth0UserId: event.user.user_id,
        email: event.user.email,
        metadata: { connection: event.connection.name, at: new Date().toISOString() }
      }),
      signal: AbortSignal.timeout(3000)
    });
  } catch (err) {
    console.log(`post-change-password: notification failed: ${err.message}`);
  }
};
