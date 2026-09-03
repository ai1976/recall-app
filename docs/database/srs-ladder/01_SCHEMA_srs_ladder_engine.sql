-- Name: [SCHEMA] SRS Ladder Epic — Phase 1 schema (rung column, mastered status, config tables)
--
-- Description:
--   Phase 1 of the SRS Ladder Epic. Adds the deterministic expanding-ladder state to
--   `reviews` and the parameterisable curve/rules config. NO SRS state on `flashcards`.
--
--   Objects created / altered:
--     1. reviews.rung            smallint NULL  + CHECK (0..20)   — the ladder position.
--                                NULL = not yet on the ladder (pre-migration / never graded
--                                under the engine). Phase 2 backfills it; submit_review sets it.
--     2. reviews_status_check    extended: 'active' | 'suspended' | 'mastered'
--                                (exact superset of the live constraint — Phase 0 Q2).
--     3. idx_reviews_user_mastered  partial index for the Phase 3 "Mastered list".
--     4. srs_ladder_curves       (question_type, rung_index, interval_days) — one row per
--                                (type, rung). Global default under question_type = '_default'.
--                                Seeded here with the approved 8-rung curve: 1/3/7/14/30/60/120/240.
--     5. srs_ladder_rules        single-row jsonb of the transition rules, read by BOTH the
--                                server (submit_review / srs_preview) and the client
--                                (get_srs_ladder_config) so the two cannot drift.
--        Both config tables: RLS ENABLED + permissive SELECT policy for anon + authenticated
--        (config is public-safe, per the auditor). NO write policy → only the service role
--        (SQL editor) edits curves/rules.
--
--   search_path: this file is pure DDL — run it as its own Supabase SQL Editor submission and
--   let it COMMIT. Do NOT append a BEGIN…ROLLBACK verification block (L3 17c lesson: the editor
--   wraps a submission in ONE transaction; a trailing ROLLBACK would silently revert the DDL).
--
--   Deploy order (non-negotiable):
--     01_SCHEMA (this file)  →  02_FUNCTIONS  →  03_TEST  →  04_MIGRATION  →  05_TEST
--     then, only after all pass, the Phase 3 frontend.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. reviews.rung
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS rung smallint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'reviews_rung_check' AND conrelid = 'public.reviews'::regclass
  ) THEN
    ALTER TABLE public.reviews
      ADD CONSTRAINT reviews_rung_check CHECK (rung IS NULL OR (rung >= 0 AND rung <= 20));
  END IF;
END $$;

COMMENT ON COLUMN public.reviews.rung IS
  'SRS ladder position (0..7 for the _default curve). NULL = not yet on the ladder. '
  'Authoritative scheduling state — submit_review computes it; get_study_queue exposes it. '
  'interval/easiness/repetition are legacy-cosmetic and no longer drive scheduling.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. reviews.status — add 'mastered'
--    Phase 0 Q2 confirmed the live definition is exactly:
--      CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])))
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_status_check;
ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_status_check
  CHECK (status = ANY (ARRAY['active'::text, 'suspended'::text, 'mastered'::text]));

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Mastered-list index (Phase 3 reads `WHERE user_id = ? AND status = 'mastered'`)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_reviews_user_mastered
  ON public.reviews (user_id)
  WHERE status = 'mastered';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. srs_ladder_curves
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.srs_ladder_curves (
  question_type text     NOT NULL,
  rung_index    smallint NOT NULL CHECK (rung_index >= 0 AND rung_index <= 20),
  interval_days integer  NOT NULL CHECK (interval_days >= 1),
  PRIMARY KEY (question_type, rung_index)
);

COMMENT ON TABLE public.srs_ladder_curves IS
  'Per-question_type rung -> interval_days. question_type = ''_default'' is the global '
  'fallback curve every current type resolves to. Edit only via the SQL editor.';

INSERT INTO public.srs_ladder_curves (question_type, rung_index, interval_days) VALUES
  ('_default', 0,   1),
  ('_default', 1,   3),
  ('_default', 2,   7),
  ('_default', 3,  14),
  ('_default', 4,  30),
  ('_default', 5,  60),
  ('_default', 6, 120),
  ('_default', 7, 240)
ON CONFLICT (question_type, rung_index)
  DO UPDATE SET interval_days = EXCLUDED.interval_days;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. srs_ladder_rules  (single row, id = 1)
--    advance.easy = 1  -> advance by 1 rung on Easy
--    advance.medium = "hold"   -> reschedule at the current rung's interval
--    advance.hard = "reset"    -> drop to rung 0
--    relearn_step_days -> Hard always reschedules to today + this (not the rung-0 interval)
--    master_threshold = 1 -> one Easy at top_rung graduates the card to status='mastered'
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.srs_ladder_rules (
  id    smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  rules jsonb    NOT NULL
);

COMMENT ON TABLE public.srs_ladder_rules IS
  'Single-row (id=1) jsonb of the ladder transition rules. Read by submit_review, '
  'srs_preview AND get_srs_ladder_config so server and client logic cannot diverge.';

INSERT INTO public.srs_ladder_rules (id, rules) VALUES (1, '{
  "top_rung": 7,
  "new_card_rung": { "hard": 0, "medium": 1, "easy": 2 },
  "advance": { "hard": "reset", "medium": "hold", "easy": 1 },
  "relearn_step_days": 1,
  "master_threshold": 1
}'::jsonb)
ON CONFLICT (id) DO UPDATE SET rules = EXCLUDED.rules;

-- ── RLS: config is public-readable, never client-writable ────────────────────
ALTER TABLE public.srs_ladder_curves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srs_ladder_rules  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS srs_ladder_curves_read ON public.srs_ladder_curves;
CREATE POLICY srs_ladder_curves_read ON public.srs_ladder_curves
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS srs_ladder_rules_read ON public.srs_ladder_rules;
CREATE POLICY srs_ladder_rules_read ON public.srs_ladder_rules
  FOR SELECT TO anon, authenticated USING (true);

GRANT SELECT ON public.srs_ladder_curves TO anon, authenticated;
GRANT SELECT ON public.srs_ladder_rules  TO anon, authenticated;
-- (no INSERT/UPDATE/DELETE grant or policy — writes are service-role only)

-- ── Sanity echo (safe SELECTs) ─────────────────────────────────────────────
SELECT 'curves' AS obj, count(*)::text AS n FROM public.srs_ladder_curves
UNION ALL
SELECT 'rules',  count(*)::text FROM public.srs_ladder_rules
UNION ALL
SELECT 'reviews.rung column',
       (SELECT data_type FROM information_schema.columns
        WHERE table_schema='public' AND table_name='reviews' AND column_name='rung')
UNION ALL
SELECT 'status check',
       (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='reviews_status_check');
