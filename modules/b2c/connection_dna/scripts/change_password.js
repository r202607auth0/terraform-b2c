/**
 * UC-07 - Self-service password reset.
 *
 * Only reached while the identifier still lives in the legacy store. Once the
 * user has been imported, Auth0 handles the reset internally and this script is
 * not called. We still notify the core so the audit trail is complete.
 */
function changePassword(identifier, newPassword, callback) {
  const axios = require('axios');

  if (configuration.LEGACY_MIGRATION_ENABLED !== 'true') {
    return callback(null, true);
  }

  axios
    .patch(
      configuration.APIM_BASE_URL + '/credentials/' + encodeURIComponent(identifier) + '/password',
      { password: newPassword, source: 'AUTH0_SSPR' },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': configuration.APIM_API_KEY
        },
        timeout: 5000,
        validateStatus: function (s) { return s < 500; }
      }
    )
    .then(function (res) {
      if (res.status === 404) return callback(null, false);
      if (res.status >= 400) return callback(new Error('APIM change_password failed: ' + res.status));
      return callback(null, true);
    })
    .catch(function (err) {
      return callback(new Error('APIM unreachable: ' + err.message));
    });
}
