-- ============================================================
-- CM50 Waitlist — Supabase Schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. WAITLIST TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.waitlist (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  email             TEXT          NOT NULL,
  first_name        TEXT,
  investment_range  TEXT,
  -- Survey fields (filled when user completes the investor survey)
  reason            TEXT,
  investing_frequency TEXT,
  objection         TEXT,
  -- Meta
  source            TEXT          DEFAULT 'website',  -- 'waitlist_top' | 'waitlist_bottom' | 'survey'
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT waitlist_email_unique UNIQUE (email),
  CONSTRAINT waitlist_email_format CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
);

-- 2. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS waitlist_email_idx        ON public.waitlist (email);
CREATE INDEX IF NOT EXISTS waitlist_created_at_idx   ON public.waitlist (created_at DESC);
CREATE INDEX IF NOT EXISTS waitlist_investment_idx   ON public.waitlist (investment_range);
CREATE INDEX IF NOT EXISTS waitlist_objection_idx    ON public.waitlist (objection);

-- 3. AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.waitlist;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.waitlist
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 4. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- Anyone can INSERT (sign up)
CREATE POLICY "allow_public_insert"
  ON public.waitlist
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Only authenticated users (admins) can SELECT
CREATE POLICY "allow_authenticated_select"
  ON public.waitlist
  FOR SELECT
  TO authenticated
  USING (true);

-- Only authenticated users can UPDATE (e.g. add survey answers to existing email)
CREATE POLICY "allow_authenticated_update"
  ON public.waitlist
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Prevent public DELETE
CREATE POLICY "deny_public_delete"
  ON public.waitlist
  FOR DELETE
  TO anon
  USING (false);

-- 5. STATS VIEW (for admin dashboard)
-- ============================================================
CREATE OR REPLACE VIEW public.waitlist_stats AS
SELECT
  COUNT(*)                                                  AS total_signups,
  COUNT(reason)                                             AS total_survey_responses,
  COUNT(CASE WHEN investment_range IN ('5000-10000','10000+') THEN 1 END) AS high_intent_count,
  COUNT(CASE WHEN investing_frequency IN ('monthly','weekly','daily') THEN 1 END) AS active_crypto_investors,
  -- Minimum capital estimate from waitlist investment_range
  SUM(CASE
    WHEN investment_range = 'under500'    THEN 0
    WHEN investment_range = '500-1000'   THEN 500
    WHEN investment_range = '1000-5000'  THEN 1000
    WHEN investment_range = '5000-10000' THEN 5000
    WHEN investment_range = '10000+'     THEN 10000
    ELSE 0
  END)                                                      AS min_capital_estimate
FROM public.waitlist;

-- 6. SIGNUPS BY DAY VIEW
-- ============================================================
CREATE OR REPLACE VIEW public.waitlist_by_day AS
SELECT
  DATE(created_at AT TIME ZONE 'UTC') AS signup_date,
  COUNT(*) AS signups
FROM public.waitlist
GROUP BY DATE(created_at AT TIME ZONE 'UTC')
ORDER BY signup_date DESC;

-- 7. GRANT VIEW ACCESS TO AUTHENTICATED ROLE
-- ============================================================
GRANT SELECT ON public.waitlist_stats TO authenticated;
GRANT SELECT ON public.waitlist_by_day TO authenticated;

-- ============================================================
-- DONE. Your waitlist table is ready.
-- Next steps:
--   1. Copy your Project URL and anon/service_role keys from
--      Supabase Dashboard → Settings → API
--   2. Update the config block in index.html and admin.html
-- ============================================================
