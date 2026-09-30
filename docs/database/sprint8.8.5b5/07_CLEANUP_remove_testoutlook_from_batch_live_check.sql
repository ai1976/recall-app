-- [CLEANUP] Undo the live check of bulk add (30/09/2026): remove TestOutlook from 'CA Intermediate May & Sept 27'
-- Description: The live check of the new Users-tab bulk add added TestOutlook (26507dc7-5ceb-4940-878e-f4cdd2f6eab3) to the live batch
--   'CA Intermediate May & Sept 27' (it was not a member before: "Added 1 student"; a repeat call correctly reported "already in the
--   batch"). A test account inside a real batch would be counted in that batch's member count and student reports, so this removes
--   the membership and the one 'batch_added' notification it produced. The audit entry is append-only and stays, by design.
--   Aborts unless exactly one matching membership exists; safe to re-run (reports "already removed").

DO $c$
DECLARE
  v_group uuid;
  v_n     integer;
BEGIN
  SELECT id INTO v_group FROM public.study_groups WHERE name = 'CA Intermediate May & Sept 27' AND is_batch_group = true;
  IF v_group IS NULL THEN
    RAISE EXCEPTION 'ABORT: batch not found';
  END IF;

  SELECT count(*) INTO v_n FROM public.study_group_members
   WHERE group_id = v_group AND user_id = '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';
  IF v_n = 0 THEN
    RAISE NOTICE 'Already removed. Nothing changed.';
    RETURN;
  END IF;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'ABORT: expected exactly 1 membership, found %', v_n;
  END IF;

  DELETE FROM public.study_group_members
   WHERE group_id = v_group AND user_id = '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';

  DELETE FROM public.notifications
   WHERE user_id = '26507dc7-5ceb-4940-878e-f4cdd2f6eab3' AND type = 'batch_added'
     AND metadata->>'group_id' = v_group::text;

  RAISE NOTICE 'Removed TestOutlook from the batch and its batch_added notification.';
END
$c$;
