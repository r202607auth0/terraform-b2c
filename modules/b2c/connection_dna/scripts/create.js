/**
 * UC-01 - Registration.
 *
 * Auth0 owns the credential, so the password is NOT forwarded to DNA. What we
 * write back is the digital-banking enrolment fact, keyed by CIF, so the core
 * knows this member now has an online profile.
 *
 * The CIF was already validated by the pre-user-registration Action; by the
 * time this runs the member is known to exist and to be un-enrolled.
 */
function create(user, callback) {
  const axios = require('axios');

  const cif = (user.app_metadata && user.app_metadata.cif) || (user.user_metadata && user.user_metadata.cif);

  if (!cif) {
    return callback(new Error('create: no CIF present on the user record'));
  }

  axios
    .post(
      configuration.APIM_BASE_URL + '/enrollments',
      {
        cif: String(cif),
        email: user.email,
        channel: 'OLB',
        enrolledAt: new Date().toISOString()
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': configuration.APIM_API_KEY,
          'Idempotency-Key': 'enroll-' + cif
        },
        timeout: 5000,
        validateStatus: function (s) { return s < 500; }
      }
    )
    .then(function (res) {
      if (res.status === 409) {
        // Already enrolled in the core. Treat as a duplicate registration.
        return callback(new ValidationError(
          'already_enrolled',
          'An online banking profile already exists for this account.'
        ));
      }
      if (res.status !== 201 && res.status !== 200) {
        return callback(new Error('APIM enrolment failed: ' + res.status));
      }
      return callback(null);
    })
    .catch(function (err) {
      return callback(new Error('APIM unreachable: ' + err.message));
    });
}
