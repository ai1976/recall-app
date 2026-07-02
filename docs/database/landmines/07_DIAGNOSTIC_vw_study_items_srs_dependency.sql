-- Name: [DIAGNOSTIC] vw_study_items Dependency on flashcards SRS Columns
-- Description: Follow-up audit triggered when 05_SCHEMA_drop_flashcards_srs_columns.sql failed
-- with `2BP01: cannot drop column next_review ... because view vw_study_items depends on it`.
-- The original L1 audit (01_DIAGNOSTIC) checked indexes / defaults / RLS / codebase reads for the
-- SRS columns, but did NOT check for VIEW/RULE dependencies via pg_depend — so this view slipped
-- through (a view read is invisible to a codebase grep). This script captures everything needed
-- to decide: recreate the view without the SRS columns (preserving its security config) then
-- retry the drop, vs. hold the SRS-column drop as a documented follow-up.
--
-- ⚠️ vw_study_items is SECURITY-SENSITIVE: it was the Jun 30 2026 anon-leak (fixed via REVOKE
-- from anon/authenticated + security_invoker=on) and is the sole data source for the
-- get_anonymous_class_stats() SECURITY DEFINER RPC. Do NOT `DROP ... CASCADE` the column (that
-- would drop the view and break the RPC). Any recreate MUST restore security_invoker=on and the
-- revoked grants exactly.
--
-- Read-only — safe to run anytime, changes nothing. Run in the Supabase SQL Editor and share all
-- four outputs.

-- ============================================
-- 1. Full view definition — which SRS columns it references, and how (SELECT list vs. WHERE/JOIN)
-- ============================================
SELECT pg_get_viewdef('public.vw_study_items', true);

-- ============================================
-- 2. Consumer RPC — does get_anonymous_class_stats actually read the SRS columns off the view,
--    or does the view merely expose them vestigially?
-- ============================================
SELECT pg_get_functiondef('public.get_anonymous_class_stats'::regproc);

-- ============================================
-- 3. Exact security config to preserve on any recreate (the Jun 30 2026 fix)
--    reloptions should contain security_invoker=on; grants should show NO anon/authenticated
-- ============================================
SELECT relname, reloptions FROM pg_class WHERE relname = 'vw_study_items';
SELECT grantee, privilege_type FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'vw_study_items';

-- ============================================
-- 4. EVERY object depending on the 4 SRS columns (the pg_depend check 01_DIAGNOSTIC should have
--    run). Tells us whether it's ONLY vw_study_items or other views/rules too.
-- ============================================
SELECT DISTINCT dep.relname AS dependent_object, dep.relkind
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dep ON dep.oid = r.ev_class
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
WHERE d.refobjid = 'public.flashcards'::regclass
  AND a.attname IN ('next_review','interval','ease_factor','repetitions');

-- ============================================
-- 5. Does ANY db function or view CONSUME vw_study_items? Frontend already confirmed dead
--    (zero `.from('vw_study_items')` in src/; Dashboard.jsx calls the get_anonymous_class_stats
--    RPC, which queries flashcards directly, not the view). If BOTH of these return zero rows,
--    vw_study_items has no consumers at all → drop the view outright (also permanently removes
--    the Jun-30-2026 anon-leak liability) → then 05_SCHEMA's column drop succeeds, no CASCADE,
--    no view recreate needed.
-- ============================================
SELECT proname FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND pg_get_functiondef(oid) ILIKE '%vw_study_items%';

SELECT viewname FROM pg_views
WHERE schemaname = 'public' AND definition ILIKE '%vw_study_items%';
