-- Name: [DIAGNOSTIC] flashcards scenario/front_text/back_text constraints
-- Description: Sprint 8.7.9 Step 0.4 — directly inspects PostgreSQL metadata
-- (not application code/docs) to confirm there is no CHECK constraint, length
-- limit, or trigger on flashcards.scenario / front_text / back_text that
-- would reject or truncate a multi-table scenario (~2,800 chars, Fixture C).
-- Run in Supabase SQL Editor and paste the full result back before Step 0
-- can be reported as confirmed.

-- 1. Column definitions (type, typmod / length limit if any)
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'flashcards'
  AND column_name IN ('scenario', 'front_text', 'back_text');

-- 2. CHECK constraints on the flashcards table (any column)
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.flashcards'::regclass
  AND contype = 'c';

-- 3. All triggers on flashcards (broad public-schema scan, not filtered by
--    event_object_table alone, per CLAUDE.md DB debugging rule)
SELECT trigger_name, event_manipulation, action_timing, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 4. RLS policies referencing flashcards (sanity check only — not expected
--    to constrain content, just confirming no WITH CHECK on these columns)
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr,
       pg_get_expr(polwithcheck, polrelid) AS with_check_expr
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass;
