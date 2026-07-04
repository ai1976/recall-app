-- Name: [DIAGNOSTIC] reviews column names for skip/suspend_card fix
-- Description: skip_card / suspend_card have an `IF NOT FOUND THEN INSERT INTO reviews (...)` branch
-- (first-ever skip/suspend of a card with no review row) that lists columns `easiness_factor` and
-- `repetitions`. The Apr 4 bug fix + CLAUDE.md say reviews uses `easiness` / `repetition`, so that
-- branch likely errors 42703. VERIFY before touching anything (CLAUDE.md: never document a root
-- cause as confirmed until a query proves it). Read-only. Spotted during L5 (04/07/2026).

-- ============================================
-- 1. Full reviews column list — names, types, nullability, defaults. Confirms:
--    (a) easiness vs easiness_factor, repetition vs repetitions (the bug),
--    (b) that interval / quality / next_review_date / skip_until / status all exist,
--    (c) whether any NOT NULL column without a default is MISSING from the INSERT (would also fail),
--    (d) the type of next_review_date (date vs timestamptz) — the INSERT passes NOW().
-- ============================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'reviews'
ORDER BY column_name;

-- ============================================
-- 2. Current live bodies of skip_card + suspend_card — confirm they match the deployed L5 versions
--    (docs/database/security/02b_...) so the fix reproduces them verbatim aside from the column names.
-- ============================================
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('skip_card', 'suspend_card')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
