-- Name: [CLEANUP] Sprint 8.6c — remove live UI-verification test cards
--
-- Description: Removes the 3 mcq_multi test cards created during live click-
-- through verification of Sprint 8.6c (manual authoring x2, CSV upload x1),
-- all clearly tagged with a unique "SPRINT8.6C" prefix in front_text and no
-- other rows sharing that prefix. Deletion attempted through the app's own
-- delete button first — blocked by the Browser pane's sandbox suppressing the
-- native confirm() dialog the button relies on (confirmed via console: "native
-- JavaScript dialogs are disabled in this browser; confirm() returned false").
-- SQL cleanup is the fallback, same pattern as bugfixes/06_CLEANUP_remove_test_row.sql
-- and sprint7.9's known-QA-row cleanup — preview first, confirm exact match,
-- delete, then reverify at 0 rows.

-- Step 1: preview — confirm exactly 3 rows match, all mcq_multi, all private
SELECT id, question_type, front_text, back_text, visibility, created_at
FROM public.flashcards
WHERE front_text ILIKE 'SPRINT8.6C%'
ORDER BY created_at;

-- Step 2: delete (only run after confirming Step 1 shows exactly the 3
-- expected test rows and nothing else)
DELETE FROM public.flashcards
WHERE front_text ILIKE 'SPRINT8.6C%'
RETURNING id, front_text;

-- Step 3: reverify at 0 rows
SELECT count(*) AS remaining
FROM public.flashcards
WHERE front_text ILIKE 'SPRINT8.6C%';
-- expect: 0
