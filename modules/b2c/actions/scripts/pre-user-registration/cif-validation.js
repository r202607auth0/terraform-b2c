/**
 * UC-01 - Validate the account number (CIF) against the credit union core
 * before the Auth0 user record is created.
 *
 * A 5-digit CIF is a bank customer, a 6-digit CIF is a trust customer. That
 * distinction drives entitlement downstream, so it is resolved here once and
 * stamped onto app_metadata rather than re-derived by every consumer.
 *
 * Secrets: APIM_BASE_URL, APIM_API_KEY, B2C_CONNECTION_NAME, ENVIRONMENT
 */

const MESSAGES = {
  en: {
    invalid_cif: 'Enter the account number exactly as it appears on your statement.',
    not_found: 'We could not match that account number. Please contact us for help.',
    already_enrolled: 'An online banking profile already exists for this account. Try signing in instead.',
    inactive: 'This account is not eligible for online banking. Please contact us.',
    unavailable: 'We cannot complete registration right now. Please try again shortly.'
  },
  'fr-CA': {
    invalid_cif: "Saisissez le numero de compte exactement comme il figure sur votre releve.",
    not_found: "Nous n'avons pas pu trouver ce numero de compte. Veuillez communiquer avec nous.",
    already_enrolled: "Un profil de services bancaires en ligne existe deja pour ce compte. Essayez d'ouvrir une session.",
    inactive: "Ce compte n'est pas admissible aux services bancaires en ligne. Veuillez communiquer avec nous.",
    unavailable: "Nous ne pouvons pas terminer l'inscription pour le moment. Veuillez reessayer sous peu."
  }
};

const msg = (lang, key) => (MESSAGES[lang] || MESSAGES.en)[key];

exports.onExecutePreUserRegistration = async (event, api) => {
  // Shared tenant: never interfere with the B2B connection.
  if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) {
    return;
  }

  const lang = (event.request && event.request.language) || 'en';
  const meta = event.user.user_metadata || {};
  const cif = String(meta.cif || '').trim();

  if (!/^\d{5}$|^\d{6}$/.test(cif)) {
    return api.access.deny('invalid_cif', msg(lang, 'invalid_cif'));
  }

  const customerType = cif.length === 5 ? 'bank' : 'trust';

  let res;
  try {
    res = await fetch(`${event.secrets.APIM_BASE_URL}/members/verify-cif`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': event.secrets.APIM_API_KEY,
        'x-correlation-id': `auth0-prereg-${event.transaction && event.transaction.id}`
      },
      body: JSON.stringify({
        cif,
        lastName: meta.last_name || undefined,
        dateOfBirth: meta.date_of_birth || undefined
      }),
      signal: AbortSignal.timeout(5000)
    });
  } catch (err) {
    // Fail closed. A registration that cannot be proven against the core must
    // not create an Auth0 identity.
    console.log(`prereg: APIM unreachable: ${err.message}`);
    return api.access.deny('core_unavailable', msg(lang, 'unavailable'));
  }

  if (res.status === 404) {
    return api.access.deny('cif_not_found', msg(lang, 'not_found'));
  }
  if (res.status === 409) {
    return api.access.deny('already_enrolled', msg(lang, 'already_enrolled'));
  }
  if (!res.ok) {
    console.log(`prereg: APIM returned ${res.status}`);
    return api.access.deny('core_unavailable', msg(lang, 'unavailable'));
  }

  const member = await res.json();

  if (member.status !== 'active') {
    return api.access.deny('account_inactive', msg(lang, 'inactive'));
  }
  if (member.customerType !== customerType) {
    console.log(`prereg: CIF length says ${customerType}, core says ${member.customerType}`);
  }

  api.user.setAppMetadata('cif', cif);
  api.user.setAppMetadata('customer_type', member.customerType || customerType);
  api.user.setAppMetadata('member_id', member.memberId);
  api.user.setAppMetadata('dna_status', member.status);
  api.user.setAppMetadata('legacy', false);
  api.user.setAppMetadata('email_on_file', true);
  api.user.setAppMetadata('registered_env', event.secrets.ENVIRONMENT);

  api.user.setUserMetadata('preferred_language', member.language || lang);
  api.user.setUserMetadata('cif', undefined); // do not leave the CIF user-writable
};
