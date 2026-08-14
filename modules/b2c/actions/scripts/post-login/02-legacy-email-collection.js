/**
 * UC-03 - Legacy user login.
 *
 * The legacy system identifies customers by username and may hold no email
 * address. Before such a user reaches the application we redirect them to a
 * hosted form, prove ownership of the address they give us with an OTP, check
 * it is not already in use, and write it back to the profile.
 *
 * Until VeriChannel ships the real screen, FORM_URL points at the mock form in
 * mocks/dna-mock, which implements the same session-token contract.
 *
 * Secrets: ACTION_SIGNING_SECRET, FORM_URL, APIM_BASE_URL, APIM_API_KEY,
 *          B2C_CONNECTION_NAME
 */

const needsEmail = (event) => {
  const app = event.user.app_metadata || {};
  if (app.legacy !== true) return false;
  if (app.email_collected === true) return false;
  return !event.user.email || app.email_on_file === false;
};

exports.onExecutePostLogin = async (event, api) => {
  if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) return;
  if (!needsEmail(event)) return;

  // api.redirect only exists in browser-based flows. The resource-owner
  // password grant used by the Postman harness has no user agent to redirect,
  // so we stamp a flag instead and let the test assert on that. Without this
  // guard every headless UC-03 test fails with an unhelpful runtime error.
  const interactive = Boolean(event.transaction) && event.request.method !== 'POST';
  if (!interactive) {
    api.user.setAppMetadata('email_collection_required', true);
    console.log(`legacy-email: non-interactive grant for ${event.user.user_id}, redirect skipped`);
    return;
  }

  const token = api.redirect.encodeToken({
    secret: event.secrets.ACTION_SIGNING_SECRET,
    expiresInSeconds: 600,
    payload: {
      sub: event.user.user_id,
      cif: (event.user.app_metadata || {}).cif,
      lang: (event.request && event.request.language) || 'en'
    }
  });

  api.redirect.sendUserTo(event.secrets.FORM_URL, {
    query: { session_token: token }
  });
};

exports.onContinuePostLogin = async (event, api) => {
  let payload;
  try {
    payload = api.redirect.validateToken({
      secret: event.secrets.ACTION_SIGNING_SECRET,
      tokenParameterName: 'session_token'
    });
  } catch (err) {
    console.log(`legacy-email: invalid continue token: ${err.message}`);
    return api.access.deny('invalid_continue_token', 'Your session expired. Please sign in again.');
  }

  const email = String(payload.email || '').trim().toLowerCase();
  const verified = payload.email_verified === true;

  if (!email || !verified) {
    return api.access.deny('email_not_verified', 'We could not confirm your email address. Please sign in again.');
  }

  // Guard against a race: the address may have been claimed while the form was open.
  try {
    const res = await fetch(
      `${event.secrets.APIM_BASE_URL}/credentials/email-in-use?email=${encodeURIComponent(email)}`,
      {
        headers: { 'x-api-key': event.secrets.APIM_API_KEY },
        signal: AbortSignal.timeout(5000)
      }
    );
    if (res.ok) {
      const body = await res.json();
      if (body.inUse === true && body.cif !== (event.user.app_metadata || {}).cif) {
        return api.access.deny('email_in_use', 'That email address is already registered. Please use a different one.');
      }
    }
  } catch (err) {
    console.log(`legacy-email: in-use check unavailable: ${err.message}`);
  }

  api.user.setAppMetadata('email_on_file', true);
  api.user.setAppMetadata('email_collected', true);
  api.user.setAppMetadata('email_collected_at', new Date().toISOString());
  api.user.setUserMetadata('pending_email', email);

  // The Actions runtime cannot change the primary email on a database user.
  // The profile write is completed by the Management API from the form backend
  // (mocks/dna-mock) or, in production, by VeriLink. See docs/use-cases/UC-03.
  console.log(`legacy-email: collected ${email} for ${event.user.user_id}`);
};
