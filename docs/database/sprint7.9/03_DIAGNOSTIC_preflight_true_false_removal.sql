-- Name: [DIAGNOSTIC] Sprint 7.9 (extended scope) pre-flight — true_false removal, merged into correct_incorrect
--
-- Description: Run BEFORE drafting the true_false-removal SCHEMA change (04_SCHEMA, once
-- this comes back). D-14 (blueprint.md §3.1) proposes retiring `true_false` as a distinct
-- question_type — CA Revision Portal's own SCHEMA.md documents correct_incorrect's renderer
-- as "Identical to true_false, with Correct/Incorrect buttons instead", and a real-usage
-- census of that sibling project found correct_incorrect used in 6 live chapters vs
-- true_false's 0 (its only occurrence sits in an orphaned legacy file no HTML page loads).
-- This diagnostic confirms the LIVE RevisOp database matches that assumption before any
-- migration is drafted — do not assume the earlier part of this sprint's QA-row deletion
-- (01_SCHEMA_sprint7.9_hygiene.sql) means these tables are still clean, re-verify.
--
-- Numbered 03_ rather than a new sprint7.10 folder — D-14 was raised mid-session, right
-- after 01/02 already ran and were verified live, but before anything was committed, so
-- it's folded into Sprint 7.9's scope as a 4th item rather than a separate sprint number.
--
-- Run all 6 queries below in the Supabase SQL Editor and paste back the full results
-- (real rows/numbers, not just row counts where row detail is requested).

-- 1. Live CHECK constraint definition — confirm both true_false and correct_incorrect are
--    still present post-Sprint-7.9 (expected: 9 values, both included).
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conname = 'chk_flashcards_question_type';

-- 2. true_false rows — full detail, not just a count. Expected 0 (the 2 that existed were
--    QA/testing artifacts deleted in Sprint 7.9) — verify, don't assume the cleanup held.
SELECT id, front_text, back_text, options, correct_answer, explanation, created_at
FROM flashcards
WHERE question_type = 'true_false'
ORDER BY created_at;

-- 3. correct_incorrect rows — full detail. Also expected 0 post-7.9, but this migration
--    doesn't touch correct_incorrect's definition — any real rows here are informational
--    only (they'd be unaffected either way), not a blocker.
SELECT id, front_text, back_text, options, correct_answer, explanation, created_at
FROM flashcards
WHERE question_type = 'correct_incorrect'
ORDER BY created_at;

-- 4. D-10 RESTRICTIVE policy pair — confirm true_false is in the IN-list (it should be,
--    unchanged by Sprint 7.9) so the removal step has something real to drop.
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
  AND polname IN ('flashcards_gate_verdict_types_insert', 'flashcards_gate_verdict_types_update');

-- 5. srs_ladder_curves — does true_false have its own per-type rung curve, or does it fall
--    back to the '_default' curve? If it has its own row(s), dropping the question_type
--    value leaves them orphaned (harmless — just unreferenced rows) but worth knowing before
--    deciding whether to clean them up in the same migration.
SELECT question_type, rung_index, interval_days
FROM srs_ladder_curves
WHERE question_type IN ('true_false', 'correct_incorrect', '_default')
ORDER BY question_type, rung_index;

-- 6. Any function body anywhere that hardcodes the string 'true_false' (beyond the CHECK
--    constraint and the two RESTRICTIVE policies already checked above) — e.g. an analytics
--    RPC with a type-specific branch, rather than being generic over question_type.
SELECT proname, prosrc
FROM pg_proc
WHERE prosrc ILIKE '%true_false%'
  AND pronamespace = 'public'::regnamespace;
