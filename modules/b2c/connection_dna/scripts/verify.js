/**
 * Fired after the customer clicks the verification link in the UC-01 activation
 * email. Propagates the verified state to the core so that DNA and Auth0 agree.
 */
function verify(identifier, callback) {
  const axios = require('axios');

  axios
    .post(
      configuration.APIM_BASE_URL + '/credentials/' + encodeURIComponent(identifier) + '/verify',
      {},
      {
        headers: { 'x-api-key': configuration.APIM_API_KEY },
        timeout: 5000,
        validateStatus: function (s) { return s < 500; }
      }
    )
    .then(function (res) {
      if (res.status === 404) return callback(null, false);
      if (res.status >= 400) return callback(new Error('APIM verify failed: ' + res.status));
      return callback(null, true);
    })
    .catch(function (err) {
      return callback(new Error('APIM unreachable: ' + err.message));
    });
}
