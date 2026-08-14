/**
 * UC-02 / UC-03 - Legacy credential validation (trickle migration).
 *
 * Auth0 calls this ONLY for identifiers it does not already hold. On a 200 the
 * profile is imported into the Auth0 store together with the password the user
 * just typed, and this script is never called for that identifier again.
 *
 * The password never reaches Fiserv DNA directly: VeriPark is the sole caller
 * of DNA, so we authenticate against the Private APIM identity facade which
 * fronts VeriPark.
 *
 * @param {string}   identifier  email address or legacy username
 * @param {string}   password
 * @param {function} callback
 */
function login(identifier, password, callback) {
  const axios = require('axios');

  // Kill switch. Once the legacy population has drained, set
  // legacy_migration_enabled = false and Auth0 becomes the only credential store.
  if (configuration.LEGACY_MIGRATION_ENABLED !== 'true') {
    return callback(new WrongUsernameOrPasswordError(identifier));
  }

  axios
    .post(
      configuration.APIM_BASE_URL + '/credentials/authenticate',
      { identifier: identifier, password: password },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': configuration.APIM_API_KEY,
          'x-correlation-id': 'auth0-login-' + Date.now()
        },
        timeout: 5000,
        validateStatus: function (s) { return s < 500; }
      }
    )
    .then(function (res) {
      if (res.status === 401 || res.status === 404) {
        return callback(new WrongUsernameOrPasswordError(identifier));
      }
      if (res.status === 423) {
        // DNA-side lockout. Surfaced to Universal Login as a generic message so
        // that no account state is disclosed to an unauthenticated caller.
        return callback(new UnauthorizedError('account_locked'));
      }
      if (res.status !== 200) {
        return callback(new Error('APIM authenticate failed with status ' + res.status));
      }

      const p = res.data;

      return callback(null, {
        user_id: String(p.cif),
        username: p.legacyUsername || undefined,
        email: p.email || undefined,
        // A legacy account with no email on file is imported unverified; the
        // post-login Action then drives the UC-03 email collection flow.
        email_verified: p.emailOnFile === true && p.emailVerified === true,
        given_name: p.firstName,
        family_name: p.lastName,
        app_metadata: {
          cif: String(p.cif),
          customer_type: p.customerType,   // "bank" (5-digit) | "trust" (6-digit)
          member_id: p.memberId,
          dna_status: p.status,
          legacy: true,
          email_on_file: p.emailOnFile === true,
          migrated_at: new Date().toISOString()
        },
        user_metadata: {
          preferred_language: p.language || 'en'
        }
      });
    })
    .catch(function (err) {
      return callback(new Error('APIM unreachable: ' + err.message));
    });
}
