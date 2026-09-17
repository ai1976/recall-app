-- Name: [DIAGNOSTIC] Sprint 8.6c preflight — mcq_multi build
--
-- Description: Run BEFORE writing/deploying 01_SCHEMA / 02_FUNCTIONS. Confirms
-- (1) the live chk_flashcards_question_type CHECK constraint's exact value list,
-- (2) both D-10 RESTRICTIVE policy bodies verbatim, (3) the exact live
-- apply_review signature via pg_get_functiondef — parameter names/types/order/
-- defaults — and that exactly ONE apply_review overload exists today, (4) the
-- live review_events column list (confirming no selected_answer column yet).
-- This project has already been bitten once by an overloaded-RPC/PostgREST-
-- ambiguity bug (blueprint.md §1.11, delete_notification/mark_single_
-- notification_read) — 02_FUNCTIONS must CREATE OR REPLACE against the exact
-- signature this query returns, not a remembered/assumed one.

-- 1. Current question_type CHECK constraint
SELECT pg_get_constraintdef(oid) AS chk_flashcards_question_type
FROM pg_constraint
WHERE conname = 'chk_flashcards_question_type';

-- 2. Both D-10 RESTRICTIVE policy bodies
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 3. Exact live apply_review signature(s) — MUST return exactly 1 row
SELECT p.oid, pg_get_functiondef(p.oid) AS full_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'apply_review';

-- 4. Confirm submit_review still delegates to apply_review (compat wrapper)
SELECT pg_get_functiondef(p.oid) AS submit_review_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'submit_review';

-- 5. Live review_events columns (confirm no selected_answer column exists yet)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'review_events'
ORDER BY ordinal_position;
