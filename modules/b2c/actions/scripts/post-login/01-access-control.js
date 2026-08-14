/**
 * UC-02 Req-3 / Req-4 / Req-5 - Access control gate.
 *
 * Runs first in the post-login chain. Everything here is a hard deny, so the
 * cheapest checks come before the ones that need metadata.
 *
 * Secrets: BLOCKED_COUNTRIES, BLOCKED_SUBDIVISIONS, B2C_CONNECTION_NAME,
 *          APIM_BASE_URL, APIM_API_KEY
 */

const MESSAGES = {
  en: {
    blocked: 'Access to your account is currently restricted. Please contact us.',
    geo: 'Online banking is not available from your current location.',
    unverified: 'Please verify your email address before signing in. We have sent you a new link.'
  },
  'fr-CA': {
    blocked: "L'acces a votre compte est actuellement restreint. Veuillez communiquer avec nous.",
    geo: "Les services bancaires en ligne ne sont pas offerts a partir de votre emplacement actuel.",
    unverified: "Veuillez verifier votre adresse courriel avant d'ouvrir une session. Nous vous avons envoye un nouveau lien."
  }
};

const msg = (lang, key) => (MESSAGES[lang] || MESSAGES.en)[key];

const list = (raw) => String(raw || '').split(',').map((s) => s.trim().toUpperCase()).filter(Boolean);

exports.onExecutePostLogin = async (event, api) => {
  if (event.connection.name !== event.secrets.B2C_CONNECTION_NAME) {
    return;
  }

  const lang = (event.request && event.request.language) || 'en';
  const app = event.user.app_metadata || {};

  // 1. Banned user, set by the fraud team or by UC-14 support-initiated lockout.
  if (app.blocked === true || app.blocked_reason) {
    console.log(`access-control: blocked user ${event.user.user_id} reason=${app.blocked_reason}`);
    return api.access.deny('user_blocked', msg(lang, 'blocked'));
  }

  // 2. Sanctioned geography.
  const geo = event.request.geoip || {};
  const country = String(geo.countryCode || '').toUpperCase();
  const subdivision = String(geo.subdivisionCode ? `${country}-${geo.subdivisionCode}` : '').toUpperCase();

  if (country && list(event.secrets.BLOCKED_COUNTRIES).includes(country)) {
    console.log(`access-control: geo deny country=${country} ip=${event.request.ip}`);
    return api.access.deny('geo_blocked', msg(lang, 'geo'));
  }
  if (subdivision && list(event.secrets.BLOCKED_SUBDIVISIONS).includes(subdivision)) {
    console.log(`access-control: geo deny subdivision=${subdivision}`);
    return api.access.deny('geo_blocked', msg(lang, 'geo'));
  }

  // 3. Email verification. Legacy users are exempt here because UC-03 collects
  //    and verifies their address later in this same chain.
  if (app.legacy !== true && event.user.email_verified === false) {
    console.log(`access-control: unverified email for ${event.user.user_id}`);
    return api.access.deny('email_unverified', msg(lang, 'unverified'));
  }

  // 4. Core-side status can change after import.
  if (app.dna_status && app.dna_status !== 'active') {
    return api.access.deny('account_inactive', msg(lang, 'blocked'));
  }
};
