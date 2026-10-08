-- Name: [DIAGNOSTIC] T-002 B-04a VERIFY (v2) - read-only record of who ran B-04a and the exact identity of every object it relies on or created
--
-- Description: TIER 0, read-only (one SELECT; it writes nothing). Run ONCE, as one selection, immediately after B-04a_SCHEMA and B-04a_TEST. It carries QA Round 53 conditions 2, 3 and 9 into the run record:
-- the login role, the identity of the B-01 functions and the B-02a index that B-04a relies on (owner, volatility, security mode, configuration, source hash), and the exact definitions of the five new constraints,
-- the trigger and the label-guard function (owner, security mode, configuration, source hash, ACL). Save the grid unchanged as docs/discussions/evidence/T-002_B04a-VERIFY-raw_08-10-2026.raw.txt.
-- Expected: current_user and session_user are postgres.

SELECT item, value FROM (
  SELECT 1 AS k, 'login' AS item, 'current_user=' || current_user || '; session_user=' || session_user AS value
  UNION ALL
  SELECT 2, 'function ' || p.oid::regprocedure::text,
         'owner=' || pg_get_userbyid(p.proowner) || '; volatility=' || p.provolatile::text || '; secdef=' || p.prosecdef || '; strict=' || p.proisstrict
         || '; config=' || coalesce(p.proconfig::text, '-') || '; src_md5=' || md5(p.prosrc) || '; acl=' || coalesce(p.proacl::text, '-')
    FROM pg_proc p
   WHERE p.oid IN ('public.normalize_course_text(text)'::regprocedure, 'public.course_catalogue_labels()'::regprocedure,
                   'public.resolve_canonical_course_label(text)'::regprocedure, 'public.fn_study_sessions_label_guard()'::regprocedure)
  UNION ALL
  SELECT 3, 'index ' || indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'disciplines_normalized_name_uidx'
  UNION ALL
  SELECT 4, 'constraint ' || conrelid::regclass::text || '.' || conname, pg_get_constraintdef(oid) || '; validated=' || convalidated
    FROM pg_constraint
   WHERE conname IN ('study_sessions_discipline_id_fkey', 'study_sessions_discipline_subject_fkey', 'study_sessions_classification_values',
                     'study_sessions_classification_shape', 'study_sessions_machine_source_unclassified', 'subjects_discipline_id_id_key')
  UNION ALL
  SELECT 5, 'trigger ' || tgname, pg_get_triggerdef(oid) || '; enabled=' || tgenabled::text || '; tgtype=' || tgtype
    FROM pg_trigger WHERE tgrelid = 'public.study_sessions'::regclass AND NOT tgisinternal
  UNION ALL
  SELECT 6, 'table acl public.study_sessions', coalesce(relacl::text, '-') FROM pg_class WHERE oid = 'public.study_sessions'::regclass
) q ORDER BY k, item;
