/**
 * Called before signup and before password reset so Auth0 can tell whether an
 * identifier already exists in the legacy store.
 *
 * Returning no user for an unknown identifier is what keeps UC-07 compliant
 * with "no PII revealed to an unauthorised user" - Auth0 shows the same
 * confirmation screen either way.
 */
function getByEmail(identifier, callback) {
  const axios = require('axios');

  if (configuration.LEGACY_MIGRATION_ENABLED !== 'true') {
    return callback(null, null);
  }

  axios
    .get(configuration.APIM_BASE_URL + '/credentials/' + encodeURIComponent(identifier), {
      headers: { 'x-api-key': configuration.APIM_API_KEY },
      timeout: 5000,
      validateStatus: function (s) { return s < 500; }
    })
    .then(function (res) {
      if (res.status === 404) return callback(null, null);
      if (res.status !== 200) return callback(new Error('APIM lookup failed: ' + res.status));

      const p = res.data;

      return callback(null, {
        user_id: String(p.cif),
        username: p.legacyUsername || undefined,
        email: p.email || undefined,
        email_verified: p.emailOnFile === true && p.emailVerified === true,
        app_metadata: {
          cif: String(p.cif),
          customer_type: p.customerType,
          member_id: p.memberId,
          dna_status: p.status,
          legacy: true,
          email_on_file: p.emailOnFile === true
        }
      });
    })
    .catch(function (err) {
      return callback(new Error('APIM unreachable: ' + err.message));
    });
}
