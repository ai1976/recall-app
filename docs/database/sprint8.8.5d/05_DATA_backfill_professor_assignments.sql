-- [DATA] Professor <-> batch assignment - STEP 3 of 4: deploy-day backfill (Sprint 8.8.5d). Run BEFORE 06 (06 refuses to run without it).
-- Description: Creates the founder-approved assignments (01/10/2026) so nobody loses access when 06 tightens the batch functions. Exact ids
--   from the 00/01 diagnostics - never names, courses, institutions or LIMIT 1:
--     Kaustubh Atre   fa44711a-8877-47fd-9541-2829cc896908  ->  CAFC May 27               7067cc26-fb43-4538-8a3f-7788641aafaf
--     CA Anand More   075ad481-13e8-45e4-9deb-3c38907eb3e6  ->  CAFC May 27               7067cc26-fb43-4538-8a3f-7788641aafaf
--                                                           ->  CA Inter May & Sept 27    77ff6271-16b3-488c-abb3-5f495eed740d
--                                                           ->  CA Final                  7c4df0e5-c08a-4b67-b682-a012d6fb5139
--     CA Niraj Mahajan 795f7baf-91f6-4ee3-958a-50d9094403a8 ->  CA Inter May & Sept 27    77ff6271-16b3-488c-abb3-5f495eed740d
--     Abhay More      d3050e85-d37d-42b5-8ea5-7e4f47894033  ->  CA Inter May & Sept 27    77ff6271-16b3-488c-abb3-5f495eed740d
--   NOT assigned: the archived "CA Intermediate - Official Study Group" (admins keep access; no professor assignment without separate
--   approval). Rows are written with assigned_by = NULL and assignment_source = 'migration_backfill' (no invented admin actor). One audit
--   entry (backfill_professor_assignments, admin_id NULL) records the list. ABORTS with nothing written if any expected professor is not an
--   active professor or any expected batch is missing / not a batch / archived. Idempotent.
-- Rollback: DELETE FROM batch_group_professors WHERE assignment_source = 'migration_backfill'; (08 does this).

DO $m$
DECLARE
  pairs constant uuid[][] := ARRAY[
    ARRAY['fa44711a-8877-47fd-9541-2829cc896908', '7067cc26-fb43-4538-8a3f-7788641aafaf'],
    ARRAY['075ad481-13e8-45e4-9deb-3c38907eb3e6', '7067cc26-fb43-4538-8a3f-7788641aafaf'],
    ARRAY['075ad481-13e8-45e4-9deb-3c38907eb3e6', '77ff6271-16b3-488c-abb3-5f495eed740d'],
    ARRAY['075ad481-13e8-45e4-9deb-3c38907eb3e6', '7c4df0e5-c08a-4b67-b682-a012d6fb5139'],
    ARRAY['795f7baf-91f6-4ee3-958a-50d9094403a8', '77ff6271-16b3-488c-abb3-5f495eed740d'],
    ARRAY['d3050e85-d37d-42b5-8ea5-7e4f47894033', '77ff6271-16b3-488c-abb3-5f495eed740d']
  ]::uuid[][];
  i int; v_prof uuid; v_grp uuid; v_inserted int := 0; v_n int; v_list jsonb := '[]'::jsonb; v_pn text; v_gn text;
BEGIN
  IF to_regclass('public.batch_group_professors') IS NULL THEN
    RAISE EXCEPTION 'Aborted: run 03 first (batch_group_professors is missing)';
  END IF;

  -- 1. Validate EVERYTHING first; nothing is written unless all pairs are valid.
  FOR i IN 1 .. array_length(pairs, 1) LOOP
    v_prof := pairs[i][1]; v_grp := pairs[i][2];
    IF (SELECT count(*) FROM public.profiles WHERE id = v_prof AND role = 'professor' AND COALESCE(status, 'active') <> 'suspended') <> 1 THEN
      RAISE EXCEPTION 'Aborted: % is not exactly one active professor', v_prof;
    END IF;
    IF (SELECT count(*) FROM public.study_groups WHERE id = v_grp AND is_batch_group = true AND archived_at IS NULL) <> 1 THEN
      RAISE EXCEPTION 'Aborted: % is not exactly one active (non-archived) batch group', v_grp;
    END IF;
  END LOOP;

  -- 2. Write.
  FOR i IN 1 .. array_length(pairs, 1) LOOP
    v_prof := pairs[i][1]; v_grp := pairs[i][2];
    INSERT INTO public.batch_group_professors (group_id, professor_id, assigned_by, assignment_source)
    VALUES (v_grp, v_prof, NULL, 'migration_backfill')
    ON CONFLICT (group_id, professor_id) DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_inserted := v_inserted + v_n;
    SELECT full_name INTO v_pn FROM public.profiles WHERE id = v_prof;
    SELECT name INTO v_gn FROM public.study_groups WHERE id = v_grp;
    v_list := v_list || jsonb_build_object('professor_id', v_prof, 'professor', v_pn, 'group_id', v_grp, 'group', v_gn, 'created', v_n = 1);
  END LOOP;

  IF v_inserted > 0 THEN
    INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
    VALUES ('backfill_professor_assignments', NULL, NULL,
            jsonb_build_object('via', 'migration sprint 8.8.5d (system backfill, no admin actor)', 'created', v_inserted, 'assignments', v_list));
  END IF;

  RAISE NOTICE 'backfill: % new assignment row(s), % expected in total', v_inserted, array_length(pairs, 1);
END $m$;

-- Visible result of the run:
SELECT p.full_name AS professor, g.name AS batch, bgp.assignment_source, bgp.assigned_by, bgp.assigned_at
FROM public.batch_group_professors bgp
JOIN public.profiles p ON p.id = bgp.professor_id
JOIN public.study_groups g ON g.id = bgp.group_id
ORDER BY p.full_name, g.name;
