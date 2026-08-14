/**
 * Shapes the ID token and access token for VeriChannel, VeriLink and the
 * Private APIM. Runs last so that everything the earlier Actions wrote to
 * metadata is visible.
 *
 * Consumers must read the namespaced claims, not raw metadata - Auth0 does not
 * put app_metadata in tokens by default and that behaviour should not be relied
 * on changing.
 *
 * Secrets: CUSTOM_CLAIM_NAMESPACE, B2C_CONNECTION_NAME, ENVIRONMENT
 */

exports.onExecutePostLogin = async (event, api) => {
  if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) return;

  const ns = event.secrets.CUSTOM_CLAIM_NAMESPACE || 'https://obp.ca/claims';
  const app = event.user.app_metadata || {};
  const user = event.user.user_metadata || {};

  const methods = (event.authentication && event.authentication.methods) || [];
  const amr = methods.map((m) => m.name);
  const mfaSatisfied = amr.some((n) => ['mfa', 'otp', 'email', 'push'].includes(n));

  const claims = {
    cif: app.cif || null,
    customer_type: app.customer_type || null,
    member_id: app.member_id || null,
    legacy: app.legacy === true,
    language: user.preferred_language || 'en',
    roles: (event.authorization && event.authorization.roles) || [],
    amr,
    acr: mfaSatisfied
      ? 'http://schemas.openid.net/pape/policies/2007/06/multi-factor'
      : 'urn:mace:incommon:iap:silver',
    env: event.secrets.ENVIRONMENT
  };

  for (const [key, value] of Object.entries(claims)) {
    api.idToken.setCustomClaim(`${ns}/${key}`, value);
    api.accessToken.setCustomClaim(`${ns}/${key}`, value);
  }
};
