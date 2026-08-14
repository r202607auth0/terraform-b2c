/**
 * Mock Private APIM identity facade.
 *
 * Stands in for: Azure Private APIM -> VeriPark VeriLink -> Fiserv DNA.
 * Implements exactly the contract in mocks/openapi/private-apim-identity.yaml,
 * so when the real APIM appears the only change anywhere in this repo is the
 * value of `apim_base_url` in environments/<env>/b2c.tfvars.
 *
 * It also hosts the UC-03 email-collection form, because an Auth0 redirect
 * Action needs somewhere to send the user before VeriChannel exists.
 *
 *   npm install && npm start
 *   npx cloudflared tunnel --url http://localhost:4010   (Auth0 must reach it)
 */

const express = require('express');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 4010;
const API_KEY = process.env.APIM_API_KEY || 'dev-mock-key';
const SIGNING_SECRET = process.env.ACTION_SIGNING_SECRET || 'dev-mock-signing-secret';
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || '';
const MGMT_CLIENT_ID = process.env.MGMT_CLIENT_ID || '';
const MGMT_CLIENT_SECRET = process.env.MGMT_CLIENT_SECRET || '';

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ---------------------------------------------------------------- state
const seed = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'seed.json'), 'utf8'));
const members = new Map(seed.members.map((m) => [m.cif, { ...m }]));
const events = [];   // everything Auth0 sent us, newest last
const otps = new Map();

const byIdentifier = (identifier) => {
  const id = String(identifier || '').toLowerCase();
  for (const m of members.values()) {
    if (m.email && m.email.toLowerCase() === id) return m;
    if (m.legacyUsername && m.legacyUsername.toLowerCase() === id) return m;
    if (m.cif === id) return m;
  }
  return null;
};

const publicProfile = (m) => ({
  cif: m.cif,
  customerType: m.customerType,
  memberId: m.memberId,
  firstName: m.firstName,
  lastName: m.lastName,
  status: m.status,
  language: m.language,
  email: m.email,
  emailOnFile: m.emailOnFile,
  emailVerified: m.emailVerified,
  legacyUsername: m.legacyUsername
});

const record = (kind, detail) => {
  const entry = { at: new Date().toISOString(), kind, ...detail };
  events.push(entry);
  if (events.length > 500) events.shift();
  console.log(`[${entry.at}] ${kind}`, JSON.stringify(detail));
};

// ---------------------------------------------------------------- auth
const requireKey = (req, res, next) => {
  if (req.get('x-api-key') !== API_KEY) {
    return res.status(401).json({ code: 'UNAUTHORIZED', message: 'x-api-key missing or wrong' });
  }
  next();
};

const api = express.Router();
api.use(requireKey);

// ---------------------------------------------------------------- UC-01
api.post('/members/verify-cif', (req, res) => {
  const cif = String(req.body.cif || '').trim();
  record('verify-cif', { cif });

  const m = members.get(cif);
  if (!m) return res.status(404).json({ code: 'CIF_NOT_FOUND', message: 'No member with that account number' });
  if (m.enrolled) return res.status(409).json({ code: 'ALREADY_ENROLLED', message: 'Member already has an online profile' });

  // Optional identity proofing. Only enforced when the caller supplies it.
  if (req.body.lastName && req.body.lastName.toLowerCase() !== m.lastName.toLowerCase()) {
    return res.status(404).json({ code: 'CIF_NOT_FOUND', message: 'Details do not match' });
  }
  if (req.body.dateOfBirth && req.body.dateOfBirth !== m.dateOfBirth) {
    return res.status(404).json({ code: 'CIF_NOT_FOUND', message: 'Details do not match' });
  }

  return res.json(publicProfile(m));
});

api.post('/enrollments', (req, res) => {
  const cif = String(req.body.cif || '').trim();
  record('enrollment', { cif, email: req.body.email });

  const m = members.get(cif);
  if (!m) return res.status(404).json({ code: 'CIF_NOT_FOUND' });
  if (m.enrolled) return res.status(409).json({ code: 'ALREADY_ENROLLED' });

  m.enrolled = true;
  m.email = req.body.email || m.email;
  m.emailOnFile = Boolean(m.email);
  return res.status(201).json({ cif: m.cif, enrolled: true });
});

api.delete('/enrollments/:id', (req, res) => {
  const m = byIdentifier(req.params.id);
  record('enrollment-deleted', { id: req.params.id, found: Boolean(m) });
  if (!m) return res.status(404).json({ code: 'NOT_FOUND' });
  m.enrolled = false;
  return res.status(204).end();
});

// ---------------------------------------------------------------- UC-02 / UC-03
api.post('/credentials/authenticate', (req, res) => {
  const { identifier, password } = req.body || {};
  const m = byIdentifier(identifier);
  record('authenticate', { identifier, matched: Boolean(m) });

  if (!m || !m.password) {
    return res.status(401).json({ code: 'INVALID_CREDENTIALS' });
  }
  if (m.lockedInCore) {
    return res.status(423).json({ code: 'ACCOUNT_LOCKED' });
  }
  if (m.password !== password) {
    return res.status(401).json({ code: 'INVALID_CREDENTIALS' });
  }
  return res.json(publicProfile(m));
});

api.get('/credentials/email-in-use', (req, res) => {
  const email = String(req.query.email || '').toLowerCase();
  const m = [...members.values()].find((x) => x.email && x.email.toLowerCase() === email);
  return res.json({ inUse: Boolean(m), cif: m ? m.cif : null });
});

api.get('/credentials/:identifier', (req, res) => {
  const m = byIdentifier(req.params.identifier);
  record('lookup', { identifier: req.params.identifier, found: Boolean(m) });
  if (!m) return res.status(404).json({ code: 'NOT_FOUND' });
  return res.json(publicProfile(m));
});

api.post('/credentials/:identifier/verify', (req, res) => {
  const m = byIdentifier(req.params.identifier);
  if (!m) return res.status(404).json({ code: 'NOT_FOUND' });
  m.emailVerified = true;
  m.emailOnFile = true;
  record('email-verified', { identifier: req.params.identifier });
  return res.json({ verified: true });
});

// ---------------------------------------------------------------- UC-07
api.patch('/credentials/:identifier/password', (req, res) => {
  const m = byIdentifier(req.params.identifier);
  record('password-changed', { identifier: req.params.identifier, source: req.body.source, found: Boolean(m) });
  if (!m) return res.status(404).json({ code: 'NOT_FOUND' });
  m.password = req.body.password;
  m.lockedInCore = false;   // SSPR lifts the core-side lock
  return res.status(204).end();
});

// ---------------------------------------------------------------- UC-11
api.post('/notifications/security-event', (req, res) => {
  record('security-event', req.body);
  return res.status(202).json({ accepted: true });
});

app.use('/identity/v1', api);

// ---------------------------------------------------------------- inspection
// Deliberately unauthenticated so Postman assertions stay simple. Never ship
// this router anywhere but a developer laptop.
app.get('/_admin/events', (req, res) => {
  const kind = req.query.kind;
  res.json(kind ? events.filter((e) => e.kind === kind) : events);
});

app.get('/_admin/members', (req, res) => res.json([...members.values()].map(publicProfile)));

app.post('/_admin/reset', (req, res) => {
  members.clear();
  JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'seed.json'), 'utf8'))
    .members.forEach((m) => members.set(m.cif, { ...m }));
  events.length = 0;
  otps.clear();
  res.json({ reset: true });
});

app.get('/_admin/otp/:sub', (req, res) => {
  // Lets an automated test read the code that a human would read in an inbox.
  const entry = otps.get(req.params.sub);
  return entry ? res.json(entry) : res.status(404).json({ code: 'NO_OTP' });
});

app.get('/health', (req, res) => res.json({ ok: true, members: members.size }));

// =====================================================================
// UC-03 email-collection form (stands in for the VeriChannel screen)
// =====================================================================

const page = (lang, inner) => `<!doctype html>
<html lang="${lang}">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Online Banking</title>
  <style>
    body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:#F4F6F9;
         margin:0;padding:40px 16px;color:#1B1F24}
    main{max-width:420px;margin:0 auto;background:#fff;border-radius:10px;padding:28px}
    h1{font-size:20px;margin:0 0 6px} p{font-size:14px;line-height:1.6;color:#43505F}
    label{display:block;font-size:14px;font-weight:600;margin:18px 0 6px}
    input{width:100%;padding:11px 12px;font-size:16px;border:1px solid #C3CBD6;border-radius:6px;box-sizing:border-box}
    button{margin-top:20px;width:100%;padding:12px;font-size:16px;font-weight:600;color:#fff;
           background:#0B5FFF;border:0;border-radius:6px;cursor:pointer}
    .err{background:#FDECEC;border-left:3px solid #D33;padding:10px 12px;font-size:14px;margin-top:16px}
    .hint{font-size:12px;color:#6B7684;margin-top:14px}
  </style>
</head>
<body><main>${inner}</main></body></html>`;

const T = {
  en: {
    title: 'Add your email address',
    intro: 'Your account does not have an email address on file. Add one so we can send you security notifications.',
    email: 'Email address', send: 'Send verification code',
    otpTitle: 'Enter your code', otpIntro: 'We sent a 6-digit code to',
    code: 'Verification code', confirm: 'Confirm', inUse: 'That email address is already registered. Please use a different one.',
    badOtp: 'That code is not correct or has expired.'
  },
  'fr-CA': {
    title: 'Ajoutez votre adresse courriel',
    intro: "Aucune adresse courriel n'est enregistree pour votre compte. Ajoutez-en une pour recevoir nos avis de securite.",
    email: 'Adresse courriel', send: 'Envoyer le code de verification',
    otpTitle: 'Saisissez votre code', otpIntro: 'Nous avons envoye un code a 6 chiffres a',
    code: 'Code de verification', confirm: 'Confirmer', inUse: "Cette adresse courriel est deja utilisee. Veuillez en choisir une autre.",
    badOtp: "Ce code est incorrect ou a expire."
  }
};

app.get('/forms/collect-email', (req, res) => {
  const { session_token: token, state } = req.query;
  let payload;
  try {
    payload = jwt.verify(token, SIGNING_SECRET);
  } catch (err) {
    return res.status(400).send(page('en', `<h1>Session expired</h1><p>Please sign in again.</p>`));
  }

  const lang = payload.lang && T[payload.lang] ? payload.lang : 'en';
  const t = T[lang];

  return res.send(page(lang, `
    <h1>${t.title}</h1>
    <p>${t.intro}</p>
    <form method="post" action="/forms/collect-email">
      <input type="hidden" name="session_token" value="${token}">
      <input type="hidden" name="state" value="${state || ''}">
      <input type="hidden" name="step" value="request-otp">
      <label for="email">${t.email}</label>
      <input id="email" name="email" type="email" required autocomplete="email">
      <button type="submit">${t.send}</button>
    </form>
    <p class="hint">Mock form &mdash; the OTP is printed to the server console and served at /_admin/otp/&lt;sub&gt;.</p>
  `));
});

app.post('/forms/collect-email', async (req, res) => {
  const { session_token: token, state, step, email, code } = req.body;

  let payload;
  try {
    payload = jwt.verify(token, SIGNING_SECRET);
  } catch (err) {
    return res.status(400).send(page('en', `<h1>Session expired</h1><p>Please sign in again.</p>`));
  }

  const lang = payload.lang && T[payload.lang] ? payload.lang : 'en';
  const t = T[lang];

  // --- step 1: address given, check availability, issue an OTP --------------
  if (step === 'request-otp') {
    const normalized = String(email || '').trim().toLowerCase();
    const clash = [...members.values()].find(
      (m) => m.email && m.email.toLowerCase() === normalized && m.cif !== payload.cif
    );

    if (clash) {
      return res.send(page(lang, `
        <h1>${t.title}</h1><div class="err">${t.inUse}</div>
        <form method="post" action="/forms/collect-email">
          <input type="hidden" name="session_token" value="${token}">
          <input type="hidden" name="state" value="${state || ''}">
          <input type="hidden" name="step" value="request-otp">
          <label for="email">${t.email}</label>
          <input id="email" name="email" type="email" required>
          <button type="submit">${t.send}</button>
        </form>`));
    }

    const otp = String(Math.floor(100000 + Math.random() * 900000));
    otps.set(payload.sub, { otp, email: normalized, expiresAt: Date.now() + 10 * 60 * 1000 });
    record('otp-issued', { sub: payload.sub, email: normalized, otp });
    console.log(`\n  ==> UC-03 OTP for ${normalized}: ${otp}\n`);

    return res.send(page(lang, `
      <h1>${t.otpTitle}</h1><p>${t.otpIntro} <strong>${normalized}</strong>.</p>
      <form method="post" action="/forms/collect-email">
        <input type="hidden" name="session_token" value="${token}">
        <input type="hidden" name="state" value="${state || ''}">
        <input type="hidden" name="step" value="verify-otp">
        <label for="code">${t.code}</label>
        <input id="code" name="code" inputmode="numeric" pattern="[0-9]{6}" required autocomplete="one-time-code">
        <button type="submit">${t.confirm}</button>
      </form>
      <p class="hint">Mock: the code is in the server console and at /_admin/otp/${encodeURIComponent(payload.sub)}.</p>`));
  }

  // --- step 2: OTP checked, profile written, control handed back to Auth0 ---
  const entry = otps.get(payload.sub);
  if (!entry || entry.otp !== String(code || '').trim() || Date.now() > entry.expiresAt) {
    return res.status(400).send(page(lang, `<h1>${t.otpTitle}</h1><div class="err">${t.badOtp}</div>`));
  }
  otps.delete(payload.sub);

  // Write the address to the core.
  const m = members.get(payload.cif);
  if (m) {
    m.email = entry.email;
    m.emailOnFile = true;
    m.emailVerified = true;
  }
  record('email-collected', { sub: payload.sub, cif: payload.cif, email: entry.email });

  // Set the primary email on the Auth0 user. The Actions runtime cannot do
  // this for a database user, so the form backend does it with the Management
  // API - in production this call belongs to VeriLink.
  if (AUTH0_DOMAIN && MGMT_CLIENT_ID && MGMT_CLIENT_SECRET) {
    try {
      const tokRes = await fetch(`https://${AUTH0_DOMAIN}/oauth/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          grant_type: 'client_credentials',
          client_id: MGMT_CLIENT_ID,
          client_secret: MGMT_CLIENT_SECRET,
          audience: `https://${AUTH0_DOMAIN}/api/v2/`
        })
      });
      const { access_token: mgmtToken } = await tokRes.json();

      const patch = await fetch(`https://${AUTH0_DOMAIN}/api/v2/users/${encodeURIComponent(payload.sub)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${mgmtToken}` },
        body: JSON.stringify({ email: entry.email, email_verified: true, connection: 'OLB-B2C-DNA' })
      });
      record('mgmt-patch', { sub: payload.sub, status: patch.status });
    } catch (err) {
      record('mgmt-patch-failed', { sub: payload.sub, error: err.message });
    }
  }

  const continueToken = jwt.sign(
    { sub: payload.sub, email: entry.email, email_verified: true },
    SIGNING_SECRET,
    { expiresIn: '5m' }
  );

  const url = `https://${AUTH0_DOMAIN}/continue?state=${encodeURIComponent(state || '')}` +
              `&session_token=${encodeURIComponent(continueToken)}`;
  return res.redirect(302, url);
});

app.listen(PORT, () => {
  console.log(`\n  DNA mock listening on http://localhost:${PORT}`);
  console.log(`  identity facade : http://localhost:${PORT}/identity/v1`);
  console.log(`  UC-03 form      : http://localhost:${PORT}/forms/collect-email`);
  console.log(`  inspection      : http://localhost:${PORT}/_admin/events\n`);
});
