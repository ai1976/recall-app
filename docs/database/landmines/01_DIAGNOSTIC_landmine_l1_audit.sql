-- Name: [DIAGNOSTIC] Landmine L1 — Pre-Drop Audit
-- Description: Ground-truth introspection for every L1 drop target (blueprint.md §1.11 #4-#8
-- plus the vestigial flashcards SRS columns). Run this FIRST, in full, in the Supabase SQL
-- Editor, and share the output before deploying any of 02/03/04/05_*.sql in this folder.
-- Read-only — safe to run anytime, changes nothing.
--
-- Codebase-side evidence (already gathered via grep, see L1 report) says all of these targets
-- are frontend-dead. This script is the DB-side half of the audit: trigger wiring, FK
-- references, RLS dependents, indexes, and — critically — whether anything still WRITES the
-- vestigial flashcards SRS columns via a DB-side DEFAULT or BEFORE INSERT trigger (frontend
-- grep only proves no CLIENT writes them; a trigger could still be writing them silently).

-- ============================================
-- 1. All triggers in public schema, by table (per CLAUDE.md: never filter by
--    event_object_table alone — full scan first)
-- ============================================
SELECT trigger_name, event_object_table, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============================================
-- 2. Confirm target #4/#5 functions exist but have NO trigger wired to them
--    (cross-reference against query 1 — none of these names should appear there)
-- ============================================
SELECT proname, prosecdef, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname = ANY (ARRAY[
    'trg_check_badge_flashcard_create', 'trg_check_badge_note_upload',
    'trg_check_badge_review', 'trg_check_badge_upvote',
    'notify_friend_request', 'notify_friend_accepted', 'notify_content_upvoted'
  ]);

-- ============================================
-- 3. Any OTHER function that calls these seven functions by name (defensive —
--    catches the case where one dead-looking function invokes another internally)
-- ============================================
SELECT proname
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND (
    pg_get_functiondef(oid) ILIKE '%trg_check_badge_%'
    OR pg_get_functiondef(oid) ILIKE '%notify_friend_request%'
    OR pg_get_functiondef(oid) ILIKE '%notify_friend_accepted%'
    OR pg_get_functiondef(oid) ILIKE '%notify_content_upvoted%'
  )
  AND proname NOT IN (
    'trg_check_badge_flashcard_create', 'trg_check_badge_note_upload',
    'trg_check_badge_review', 'trg_check_badge_upvote',
    'notify_friend_request', 'notify_friend_accepted', 'notify_content_upvoted'
  );

-- ============================================
-- 4. comments table — FK references INTO it, RLS policies, and row count
-- ============================================
SELECT conname, conrelid::regclass AS referencing_table, confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE confrelid = 'public.comments'::regclass;

SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'comments';

SELECT count(*) AS comments_row_count FROM public.comments;

-- Any function/view referencing the comments table by name
SELECT proname
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND pg_get_functiondef(oid) ILIKE '%comments%';

SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public' AND definition ILIKE '%comments%';

-- ============================================
-- 5. Column-drop targets — indexes, defaults, and whether ANY row has non-null data
--    (non-null data doesn't block a drop, but tells us if the column is still being
--    written by something we haven't found yet)
-- ============================================
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE tablename IN ('notes', 'flashcards', 'upvotes')
ORDER BY tablename, indexname;

SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    (table_name = 'notes' AND column_name IN ('course', 'subject', 'topic'))
    OR (table_name = 'upvotes' AND column_name = 'note_id')
    OR (table_name = 'flashcards' AND column_name IN ('next_review', 'interval', 'ease_factor', 'repetitions'))
  );

SELECT 'notes.course'  AS col, count(*) FILTER (WHERE course  IS NOT NULL) AS non_null_rows FROM public.notes
UNION ALL
SELECT 'notes.subject', count(*) FILTER (WHERE subject IS NOT NULL) FROM public.notes
UNION ALL
SELECT 'notes.topic',   count(*) FILTER (WHERE topic   IS NOT NULL) FROM public.notes
UNION ALL
SELECT 'upvotes.note_id', count(*) FILTER (WHERE note_id IS NOT NULL) FROM public.upvotes
UNION ALL
SELECT 'flashcards.next_review',  count(*) FILTER (WHERE next_review  IS NOT NULL) FROM public.flashcards
UNION ALL
SELECT 'flashcards.interval',     count(*) FILTER (WHERE interval     IS NOT NULL) FROM public.flashcards
UNION ALL
SELECT 'flashcards.ease_factor',  count(*) FILTER (WHERE ease_factor  IS NOT NULL) FROM public.flashcards
UNION ALL
SELECT 'flashcards.repetitions',  count(*) FILTER (WHERE repetitions  IS NOT NULL) FROM public.flashcards;

-- Most recent non-null write to each SRS column, to sanity-check the "write-only,
-- FlashcardCreate.jsx is the sole writer" hypothesis: if max(created_at) for rows with a
-- non-null SRS value is recent, the client insert payload (which is being removed in the
-- companion frontend change) is almost certainly the writer, not a DB trigger/default.
SELECT max(created_at) AS most_recent_row_with_srs_data
FROM public.flashcards
WHERE next_review IS NOT NULL OR interval IS NOT NULL
   OR ease_factor IS NOT NULL OR repetitions IS NOT NULL;

-- ============================================
-- 6. RLS policies on notes/flashcards/upvotes that might reference the target columns
--    directly (defensive — a policy predicate on a legacy column would block the drop)
-- ============================================
SELECT tablename, policyname, qual, with_check
FROM pg_policies
WHERE tablename IN ('notes', 'flashcards', 'upvotes')
  AND (
    qual ILIKE '%course%' OR qual ILIKE '%.subject%' OR qual ILIKE '%.topic%'
    OR with_check ILIKE '%course%' OR with_check ILIKE '%.subject%' OR with_check ILIKE '%.topic%'
  );
