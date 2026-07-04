-- Name: [DIAGNOSTIC] profiles FK cascade audit (L4 pre-fix)
-- Description: L4 fixes the last catalogued landmine (§1.11 "Newly found Jun 30"): the
-- profiles.id -> auth.users.id FK is ON DELETE NO ACTION, so deleting a user from the Supabase
-- Auth dashboard fails ("Database error deleting user") until the profiles row is removed by hand.
-- Fix = make that FK ON DELETE CASCADE. But cascading through profiles will try to delete every
-- row that references profiles(id); if ANY of those child FKs is itself NO ACTION/RESTRICT, the
-- delete still fails one level down. This audit maps the whole dependency graph BEFORE the fix.
-- Read-only. confdeltype legend: a = NO ACTION, r = RESTRICT, c = CASCADE, n = SET NULL, d = SET DEFAULT.

-- ============================================
-- 1. The target constraint: profiles -> auth.users delete action. Expect 'a' (NO ACTION) = the bug.
-- ============================================
SELECT
  con.conname,
  con.confdeltype,
  CASE con.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
       WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete
FROM pg_constraint con
WHERE con.conrelid = 'public.profiles'::regclass
  AND con.contype = 'f'
  AND con.confrelid = 'auth.users'::regclass;

-- ============================================
-- 2. THE CRITICAL LIST — every FK that references public.profiles(id), with its ON DELETE action.
--    Any row here with on_delete = NO ACTION or RESTRICT is a downstream blocker that L4's fix must
--    convert (to CASCADE where child data should die with the user, or SET NULL where attribution
--    should be preserved, e.g. contributed_by / featured_*_by / creator_id).
-- ============================================
SELECT
  con.conrelid::regclass                              AS child_table,
  att.attname                                         AS child_column,
  con.conname                                         AS constraint_name,
  CASE con.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
       WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete
FROM pg_constraint con
JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord) ON true
JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = k.attnum
WHERE con.contype = 'f'
  AND con.confrelid = 'public.profiles'::regclass
ORDER BY on_delete, child_table, child_column;

-- ============================================
-- 3. FKs that reference auth.users(id) DIRECTLY (not via profiles). These are unaffected by the
--    profiles fix but worth knowing — if any are NO ACTION they independently block user deletion.
-- ============================================
SELECT
  con.conrelid::regclass AS child_table,
  con.conname            AS constraint_name,
  CASE con.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
       WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete
FROM pg_constraint con
WHERE con.contype = 'f'
  AND con.confrelid = 'auth.users'::regclass
ORDER BY on_delete, child_table;

-- ============================================
-- 4. Blast-radius sanity: how many child rows would cascade for the user with the most content.
--    (Pure information — confirms the delete does real work and roughly how much.)
-- ============================================
SELECT
  (SELECT count(*) FROM notes       WHERE user_id = t.id) AS notes,
  (SELECT count(*) FROM flashcards  WHERE user_id = t.id) AS flashcards,
  (SELECT count(*) FROM reviews     WHERE user_id = t.id) AS reviews,
  t.id AS sample_user_id
FROM (
  SELECT p.id
  FROM profiles p
  ORDER BY (SELECT count(*) FROM flashcards f WHERE f.user_id = p.id) DESC
  LIMIT 1
) t;
