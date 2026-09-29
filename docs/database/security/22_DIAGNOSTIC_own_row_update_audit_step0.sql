-- ============================================================================
-- Name: [DIAGNOSTIC] Own-row UPDATE audit - Step 0 catalog facts (friendships, reviews, profile_courses, counters)
-- Description: READ ONLY. Follow-up to 18_DIAGNOSTIC block 5, which listed public tables whose UPDATE
--   policy has no WITH CHECK. This establishes, from the catalog, what a signed-in client can actually
--   do on each, before any fix is designed. Run each block separately and paste each result under its
--   label. Nothing here writes anything.
-- ============================================================================

-- ── A. ALL policies (every command) on the tables under audit ────────────────
SELECT tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('friendships','reviews','profile_courses','notes','flashcards','flashcard_decks',
                    'notifications','push_subscriptions','user_stats','user_badges')
ORDER BY tablename, cmd, policyname;

-- ── B. Effective table privileges for client roles ───────────────────────────
SELECT t AS table_name,
       has_table_privilege('authenticated', 'public.' || t, 'INSERT') AS auth_insert,
       has_table_privilege('authenticated', 'public.' || t, 'UPDATE') AS auth_update,
       has_table_privilege('authenticated', 'public.' || t, 'DELETE') AS auth_delete,
       has_table_privilege('anon',          'public.' || t, 'UPDATE') AS anon_update
FROM unnest(ARRAY['friendships','reviews','profile_courses','notes','flashcards','flashcard_decks',
                  'notifications','push_subscriptions','user_stats','user_badges']) AS t;

-- ── C. Triggers on those tables (definition, so BEFORE-guards vs AFTER-counters are visible) ──
SELECT c.relname AS table_name, t.tgname, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND NOT t.tgisinternal
  AND c.relname IN ('friendships','reviews','profile_courses','notes','flashcards','flashcard_decks',
                    'notifications','push_subscriptions','user_stats','user_badges')
ORDER BY c.relname, t.tgname;

-- ── D. friendships ───────────────────────────────────────────────────────────
-- D1. CHECK/unique constraints.
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'public.friendships'::regclass;

-- D2. Functions that WRITE friendships (are there SECURITY DEFINER accept/send paths, or is it all client-direct?).
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosrc ~* '(insert\s+into|update|delete\s+from)\s+(public\.)?friendships'
ORDER BY p.proname;

-- D3. What does the friendship counter / badge trigger do (gaming impact of self-accepting)?
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('fn_update_friendships_counter', 'fn_badge_check_friendships');

-- D4. What does an ACCEPTED friendship unlock? Policies and functions that read friendships.
SELECT 'policy' AS kind, tablename AS object, policyname AS name
FROM pg_policies WHERE schemaname = 'public' AND (qual ILIKE '%friendships%' OR with_check ILIKE '%friendships%')
UNION ALL
SELECT 'function', p.proname, pg_get_function_identity_arguments(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosrc ILIKE '%friendships%' AND p.proname NOT ILIKE 'fn_%counter%'
ORDER BY kind, object;

-- D5. Current data shape: any friendship already accepted whose sender == recipient, or self-rows, or
--     rows where updated_at is later than created_at with status accepted by the SENDER's session cannot
--     be known - but self-pairs and duplicates are checkable.
SELECT COUNT(*) FILTER (WHERE user_id = friend_id)                      AS self_pairs,
       COUNT(*) FILTER (WHERE status = 'accepted')                       AS accepted_rows,
       COUNT(*) FILTER (WHERE status = 'pending')                        AS pending_rows,
       COUNT(*) FILTER (WHERE status = 'rejected')                       AS rejected_rows,
       COUNT(*)                                                          AS total_rows
FROM public.friendships;

-- ── E. reviews: who can legitimately write it? ───────────────────────────────
-- E1. Functions that write reviews (all should be SECURITY DEFINER; a non-definer writer would break if
--     client write privileges were revoked).
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
       p.prosecdef AS security_definer, pg_get_userbyid(p.proowner) AS owner
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosrc ~* '(insert\s+into|update|delete\s+from)\s+(public\.)?reviews\M'
ORDER BY p.prosecdef, p.proname;

-- E2. Triggers ON reviews and their functions' security mode (they run with the caller's rights inside
--     a definer RPC, so revoking client write privileges must not break them).
SELECT t.tgname, p.proname AS function_name, p.prosecdef AS security_definer
FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'public.reviews'::regclass AND NOT t.tgisinternal;

-- ── F. profile_courses: does the DATABASE trust it for anything? ─────────────
-- F1. Functions/policies that reference it (expected: none - only client CourseContext reads it).
SELECT 'function' AS kind, p.proname AS name
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosrc ILIKE '%profile_courses%'
UNION ALL
SELECT 'policy', tablename || '.' || policyname
FROM pg_policies WHERE schemaname = 'public'
  AND (qual ILIKE '%profile_courses%' OR with_check ILIKE '%profile_courses%')
UNION ALL
SELECT 'view', c.relname
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('v','m') AND pg_get_viewdef(c.oid) ILIKE '%profile_courses%';

-- F2. Columns and who holds rows now (professors only expected).
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profile_courses'
ORDER BY ordinal_position;

SELECT p.role, COUNT(*) AS rows FROM public.profile_courses pc JOIN public.profiles p ON p.id = pc.user_id GROUP BY p.role;

-- ── G. Owner-editable counters / privileged-looking columns on content tables ──
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('notes','flashcards','flashcard_decks')
  AND (column_name ~* '(count|score|featured|verified|pinned|rank|approved|is_official|is_admin|moderat)')
ORDER BY table_name, column_name;
