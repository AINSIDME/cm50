/**
 * CM50 — Supabase Client
 * Shared between index.html and admin.html
 *
 * SETUP: Replace the two constants below with your project values.
 * Dashboard → Settings → API → Project URL / anon public key
 */

export const SUPABASE_URL      = 'https://hshmyqmbogjoowrksbav.supabase.co';   // e.g. https://xyzabc.supabase.co
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzaG15cW1ib2dqb293cmtzYmF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMDM0MDEsImV4cCI6MjA5Nzc3OTQwMX0.uBhZBjonz321oj1-wRdGGn6qC7YYQw-sxz-bqznxDTg';      // starts with "eyJ…"

// ── lazy singleton ────────────────────────────────────────────
let _client = null;

export function getClient() {
  if (_client) return _client;
  if (!window.supabase) throw new Error('Supabase SDK not loaded');
  _client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true },
  });
  return _client;
}

// ── email validation ─────────────────────────────────────────
export function isValidEmail(email) {
  return /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/.test(email.trim());
}

// ── waitlist INSERT (public, anon) ───────────────────────────
/**
 * @param {object} data
 * @param {string} data.email
 * @param {string} [data.first_name]
 * @param {string} [data.investment_range]
 * @param {string} [data.reason]
 * @param {string} [data.investing_frequency]
 * @param {string} [data.objection]
 * @param {string} [data.source]
 * @returns {{ data, error, isDuplicate }}
 */
export async function insertWaitlistEntry(data) {
  const sb = getClient();
  const payload = {
    email:               data.email.trim().toLowerCase(),
    first_name:          data.first_name?.trim() || null,
    investment_range:    data.investment_range   || null,
    reason:              data.reason             || null,
    investing_frequency: data.investing_frequency|| null,
    objection:           data.objection          || null,
    source:              data.source             || 'website',
  };

  const { data: row, error } = await sb
    .from('waitlist')
    .insert(payload)
    .select('id')
    .single();

  const isDuplicate = error?.code === '23505'; // Postgres unique violation
  return { data: row, error, isDuplicate };
}

/**
 * Upsert survey answers onto an existing email row.
 * Safe to call even if the row doesn't exist yet (will create it).
 */
export async function upsertSurveyAnswers(email, surveyData) {
  const sb = getClient();
  const { data, error } = await sb
    .from('waitlist')
    .upsert({
      email:               email.trim().toLowerCase(),
      reason:              surveyData.reason              || null,
      investing_frequency: surveyData.investing_frequency || null,
      objection:           surveyData.objection           || null,
      source:              'survey',
    }, { onConflict: 'email', ignoreDuplicates: false })
    .select('id')
    .single();
  return { data, error };
}

// ── total count (anon-safe via RPC or count trick) ───────────
export async function getWaitlistCount() {
  const sb = getClient();
  const { count, error } = await sb
    .from('waitlist')
    .select('*', { count: 'exact', head: true });
  return error ? 0 : (count ?? 0);
}
