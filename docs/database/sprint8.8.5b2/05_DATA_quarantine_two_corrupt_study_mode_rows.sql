-- [DATA] Quarantine + remove the two unequivocally corrupt Study Mode rows (stale-timer bug, D-46)
-- Description: Both rows were produced by the old `now - stored started_at` timer closing a session that had been
--   abandoned for weeks/months:
--     * Avantika Hagawane (1de7a5d4-c780-4a5b-be53-47b95bb9e308) - id 687abe30-93f8-4c88-b114-bb07a065d886,
--       started 31/08/2026 04:58 UTC, ended 29/09/2026 18:15 UTC, 2,553,404 s (709.28 h)
--     * user 075ad481-13e8-45e4-9deb-3c38907eb3e6 - one study_mode row of 14,749,689 s (4,097.1 h)
--   Steps (one atomic run - the SQL editor wraps it in a single transaction, so any failed guard rolls everything back):
--     1. create public.study_sessions_quarantine (a copy of the study_sessions columns + reason / timestamp / reference).
--        RLS enabled with NO policies and all client privileges revoked, so no student can ever read it.
--     2. copy the two rows into it, verbatim, with reason 'stale_timer_over_max_duration'
--     3. delete exactly those two rows from study_sessions
--   Deliberately NOT touched: the 6.4 h study_mode row, the 11.7 h practice_mode row, and every long manual row -
--   suspicious, but not conclusively explained by this defect.
--   Downstream: the 7 functions that read study_sessions (dashboard stats, leaderboards, heatmap, group stats) all
--   sum the table live; the 01 diagnostic found no view / materialized view / cron job / stored total. Removing the
--   rows therefore corrects every figure automatically; nothing needs recalculating.
--   Safe to re-run: if the rows are already quarantined it reports that and changes nothing.
-- Guards: aborts unless exactly the two expected rows are found (id + user + source + duration all matching).

CREATE TABLE IF NOT EXISTS public.study_sessions_quarantine (
  id                uuid        NOT NULL,
  user_id           uuid        NOT NULL,
  started_at        timestamptz NOT NULL,
  ended_at          timestamptz NOT NULL,
  duration_seconds  integer     NOT NULL,
  session_date      date        NOT NULL,
  source            text        NOT NULL,
  category          text,
  created_at        timestamptz,
  session_id        uuid,
  quarantine_reason text        NOT NULL,
  quarantined_at    timestamptz NOT NULL DEFAULT now(),
  remediation_ref   text        NOT NULL,
  CONSTRAINT study_sessions_quarantine_pkey PRIMARY KEY (id)
);

ALTER TABLE public.study_sessions_quarantine ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.study_sessions_quarantine FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.study_sessions_quarantine IS
  'Audit copy of study_sessions rows removed as corrupt. Server-side only: RLS on, no policies, no client grants. Sprint 8.8.5b2 / D-46.';

DO $rem$
DECLARE
  v_avantika_id  constant uuid := '687abe30-93f8-4c88-b114-bb07a065d886';
  v_avantika_uid constant uuid := '1de7a5d4-c780-4a5b-be53-47b95bb9e308';
  v_other_uid    constant uuid := '075ad481-13e8-45e4-9deb-3c38907eb3e6';
  v_found        int;
  v_already      int;
  v_ids          uuid[];
BEGIN
  SELECT count(*) INTO v_already FROM public.study_sessions_quarantine
   WHERE quarantine_reason = 'stale_timer_over_max_duration';
  SELECT count(*) INTO v_found FROM public.study_sessions s
   WHERE s.source = 'study_mode'
     AND ((s.id = v_avantika_id AND s.user_id = v_avantika_uid AND s.duration_seconds = 2553404)
       OR (s.user_id = v_other_uid AND s.duration_seconds = 14749689));

  IF v_found = 0 AND v_already >= 2 THEN
    RAISE NOTICE 'Already remediated: % rows in quarantine, none left in study_sessions. Nothing changed.', v_already;
    RETURN;
  END IF;
  IF v_found <> 2 THEN
    RAISE EXCEPTION 'ABORT: expected exactly 2 corrupt rows in study_sessions, found % (already quarantined: %). Nothing changed.', v_found, v_already;
  END IF;

  SELECT array_agg(s.id) INTO v_ids FROM public.study_sessions s
   WHERE s.source = 'study_mode'
     AND ((s.id = v_avantika_id AND s.user_id = v_avantika_uid AND s.duration_seconds = 2553404)
       OR (s.user_id = v_other_uid AND s.duration_seconds = 14749689));

  INSERT INTO public.study_sessions_quarantine
    (id, user_id, started_at, ended_at, duration_seconds, session_date, source, category, created_at, session_id,
     quarantine_reason, remediation_ref)
  SELECT s.id, s.user_id, s.started_at, s.ended_at, s.duration_seconds, s.session_date, s.source, s.category,
         s.created_at, s.session_id,
         'stale_timer_over_max_duration',
         'Sprint 8.8.5b2 / D-46 / 30-09-2026 - old now-minus-started_at timer closed an abandoned session'
    FROM public.study_sessions s
   WHERE s.id = ANY (v_ids);

  DELETE FROM public.study_sessions WHERE id = ANY (v_ids);

  IF (SELECT count(*) FROM public.study_sessions WHERE id = ANY (v_ids)) <> 0
     OR (SELECT count(*) FROM public.study_sessions_quarantine WHERE id = ANY (v_ids)) <> 2 THEN
    RAISE EXCEPTION 'ABORT: post-check failed (rows not fully moved). Rolled back.';
  END IF;
  RAISE NOTICE 'Quarantined and removed 2 corrupt study_mode rows: %', v_ids;
END
$rem$;
