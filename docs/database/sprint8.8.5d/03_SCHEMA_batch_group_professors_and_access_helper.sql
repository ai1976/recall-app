-- [SCHEMA] Professor <-> batch assignment - STEP 1 of 4: table + central access helper (Sprint 8.8.5d). ADDITIVE; changes no existing function.
-- Description: Professors currently see EVERY active batch because the batch functions gate on role only (00 diagnostic, live bodies).
--   This file adds the authority that will replace that role-only gate:
--     batch_group_professors   one row per (batch, professor). RLS ENABLED, ZERO policies, ALL privileges revoked from PUBLIC / anon /
--                              authenticated - clients can only reach it through the SECURITY DEFINER functions. NOT group membership.
--                              assigned_by is the acting admin; migration-created rows carry assigned_by = NULL and
--                              assignment_source = 'migration_backfill' (no invented actor).
--     batch_group_access_denial(actor, group, need)   THE single place that answers "may this person act on / look at this batch".
--                              need = 'manage'     active admin / super_admin, batch must exist, be a batch and NOT archived (assign)
--                                     'admin_view' active admin / super_admin, batch must exist and be a batch (archived allowed)
--                                     'view'       'admin_view' OR an ASSIGNED, currently-ACTIVE professor (profiles.role = 'professor' and
--                                                  not suspended, checked at call time, so demotion/suspension revokes access even though
--                                                  the assignment row stays)
--                              Returns NULL when allowed, else a reason (not_authenticated / account_inactive / not_authorized /
--                              batch_not_found / not_a_batch / batch_archived). Authorization is decided BEFORE any group-existence
--                              answer, so an unauthorised caller cannot probe which batch ids exist. Internal: no client role can execute it.
--                              FUTURE (B2B): institution scoping is ONE edit here (an 'admin' may only reach batches of their own institution).
-- Rollback: 08. Test: 07 (run after 06).

CREATE TABLE IF NOT EXISTS public.batch_group_professors (
  group_id          uuid        NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  professor_id      uuid        NOT NULL REFERENCES public.profiles(id)     ON DELETE CASCADE,
  assigned_by       uuid        REFERENCES public.profiles(id)              ON DELETE SET NULL,
  assigned_at       timestamptz NOT NULL DEFAULT now(),
  assignment_source text        NOT NULL DEFAULT 'admin' CHECK (assignment_source IN ('admin', 'migration_backfill')),
  PRIMARY KEY (group_id, professor_id)
);

CREATE INDEX IF NOT EXISTS idx_batch_group_professors_professor ON public.batch_group_professors (professor_id);

ALTER TABLE public.batch_group_professors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.batch_group_professors FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.batch_group_access_denial(p_actor uuid, p_group_id uuid, p_need text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_role     text;
  v_status   text;
  v_is_batch boolean;
  v_archived timestamptz;
BEGIN
  IF p_need IS NULL OR p_need NOT IN ('manage', 'admin_view', 'view') THEN
    RAISE EXCEPTION 'batch_group_access_denial: unknown need %', p_need;
  END IF;
  IF p_actor IS NULL THEN
    RETURN 'not_authenticated';
  END IF;

  SELECT role, status INTO v_role, v_status FROM public.profiles WHERE id = p_actor;
  IF NOT FOUND OR COALESCE(v_status, 'active') = 'suspended' THEN
    RETURN 'account_inactive';
  END IF;

  IF v_role NOT IN ('admin', 'super_admin') THEN
    -- Only the 'view' need can be satisfied by a professor, and only through an explicit assignment to THIS batch.
    IF p_need <> 'view'
       OR v_role <> 'professor'
       OR NOT EXISTS (SELECT 1 FROM public.batch_group_professors bgp WHERE bgp.group_id = p_group_id AND bgp.professor_id = p_actor) THEN
      RETURN 'not_authorized';
    END IF;
  END IF;

  SELECT is_batch_group, archived_at INTO v_is_batch, v_archived FROM public.study_groups WHERE id = p_group_id;
  IF NOT FOUND THEN
    RETURN 'batch_not_found';
  END IF;
  IF v_is_batch IS NOT TRUE THEN
    RETURN 'not_a_batch';
  END IF;
  IF p_need = 'manage' AND v_archived IS NOT NULL THEN
    RETURN 'batch_archived';
  END IF;

  -- FUTURE (B2B): institution scoping goes here, once, for every batch function that calls this helper.
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.batch_group_access_denial(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
