-- [DIAGNOSTIC] What can block deleting a user's profile? (found by 09 test U4, 30/09/2026)
-- Description: READ-ONLY. admin_delete_user_data() removes a user's rows from six tables and then their profile row. Test U4
--   showed the profile delete can be blocked by a foreign key from ANOTHER table with no delete rule:
--   flashcard_batch_provenance.created_by -> profiles(id). This lists every foreign key that points at profiles(id) so the
--   function can be made complete, and shows how many rows each would affect for real users.
-- Run each block separately and paste all results.

-- Block 1: every foreign key that points at profiles(id), with its delete rule
--   confdeltype: a = NO ACTION (blocks the delete), r = RESTRICT (blocks), c = CASCADE, n = SET NULL, d = SET DEFAULT
SELECT c.conrelid::regclass AS referencing_table,
       a.attname            AS referencing_column,
       CASE c.confdeltype WHEN 'a' THEN 'NO ACTION (blocks)' WHEN 'r' THEN 'RESTRICT (blocks)'
                          WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
       NOT a.attnotnull     AS column_is_nullable
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
WHERE c.contype = 'f' AND c.confrelid = 'public.profiles'::regclass
ORDER BY (c.confdeltype IN ('a', 'r')) DESC, 1, 2;

-- Block 2: the table that blocked the test - structure and what points at it
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcard_batch_provenance'
ORDER BY ordinal_position;

SELECT c.conrelid::regclass AS table_name, c.conname, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.contype = 'f'
  AND (c.conrelid = 'public.flashcard_batch_provenance'::regclass OR c.confrelid = 'public.flashcard_batch_provenance'::regclass);

SELECT count(*) AS provenance_rows, count(DISTINCT created_by) AS distinct_creators
FROM public.flashcard_batch_provenance;

-- Block 3: how many users (by role) own provenance rows - i.e. who would currently be UNDELETABLE
SELECT p.role, count(DISTINCT fp.created_by) AS users_with_provenance, count(*) AS rows
FROM public.flashcard_batch_provenance fp
JOIN public.profiles p ON p.id = fp.created_by
GROUP BY p.role
ORDER BY p.role;

-- Block 4: for each blocking (NO ACTION / RESTRICT) foreign key, how many rows belong to STUDENTS today
--          (run only the tables Block 1 lists as blocking; flashcard_batch_provenance shown as the known example)
SELECT 'flashcard_batch_provenance.created_by' AS reference,
       count(*) FILTER (WHERE p.role = 'student') AS student_rows,
       count(*) AS total_rows
FROM public.flashcard_batch_provenance fp
JOIN public.profiles p ON p.id = fp.created_by;
