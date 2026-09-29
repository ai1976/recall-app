-- ============================================================================
-- Name: [DIAGNOSTIC] Sprint 8.8.5c Step 0 (part 2) - missing blocks + profiles write-safety check
-- Description: READ ONLY. Re-run of the blocks from 00_ whose results did not come back (each of these
--   pasted as a copy of a different block), plus a targeted check of who can UPDATE which columns of
--   `profiles` - relevant to the RPC-vs-trigger decision and to a possible role-escalation path.
--   Run each block separately; paste each result under its label.
-- ============================================================================

-- ── A1. my_cards_enrollment columns ──────────────────────────────────────────
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'my_cards_enrollment'
ORDER BY ordinal_position;

-- ── A2. my_cards_enrollment constraints (need the exact status CHECK text) ───
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.my_cards_enrollment'::regclass;

-- ── B4. Every public function that UPDATEs profiles.course_level ─────────────
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%course_level%'
  AND p.prosrc ~* 'update\s+(public\.)?profiles'
ORDER BY p.proname;

-- ── B5. Role values ──────────────────────────────────────────────────────────
SELECT role, COUNT(*) AS n FROM public.profiles GROUP BY role ORDER BY n DESC;

-- ── C3. Course strings in use (profiles vs cards vs discipline names) ────────
SELECT 'profiles.course_level' AS source, course_level AS course, COUNT(*) AS n
FROM public.profiles GROUP BY 2
UNION ALL
SELECT 'flashcards.target_course', target_course, COUNT(*) FROM public.flashcards GROUP BY 2
UNION ALL
SELECT 'disciplines.name', name, 1 FROM public.disciplines
ORDER BY source, n DESC;

-- ── F1. Can a signed-in client UPDATE sensitive profiles columns directly?
--        (Effective privilege after table- AND column-level grants.) ──────────
SELECT c AS column_name,
       has_column_privilege('authenticated', 'public.profiles', c, 'UPDATE') AS authenticated_can_update,
       has_column_privilege('anon',          'public.profiles', c, 'UPDATE') AS anon_can_update
FROM unnest(ARRAY['role','course_level','email','full_name']) AS c;

-- ── F2. What does is_admin() / is_super_admin() actually read? (does trusting profiles.role matter?) ──
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('is_admin', 'is_super_admin');

-- ── F3. Any RLS policy or trigger on profiles that restricts WHICH columns an own-row UPDATE may change?
--        (Policies were already listed in 00_ B2; this is the trigger side, profiles only, all events.) ──
SELECT tgname, tgenabled, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t
WHERE t.tgrelid = 'public.profiles'::regclass AND NOT t.tgisinternal;
