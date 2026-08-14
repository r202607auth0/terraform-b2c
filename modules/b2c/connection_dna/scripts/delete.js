/**
 * Deregisters the online-banking profile. The member record in DNA is never
 * deleted from here - only the OLB enrolment is withdrawn.
 */
function remove(id, callback) {
  const axios = require('axios');

  axios
    .delete(configuration.APIM_BASE_URL + '/enrollments/' + encodeURIComponent(id), {
      headers: { 'x-api-key': configuration.APIM_API_KEY },
      timeout: 5000,
      validateStatus: function (s) { return s < 500; }
    })
    .then(function (res) {
      if (res.status >= 400 && res.status !== 404) {
        return callback(new Error('APIM delete failed: ' + res.status));
      }
      return callback(null);
    })
    .catch(function (err) {
      return callback(new Error('APIM unreachable: ' + err.message));
    });
}
