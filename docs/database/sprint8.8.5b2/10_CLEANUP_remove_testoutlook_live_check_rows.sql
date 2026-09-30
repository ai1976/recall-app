-- [CLEANUP] Remove the three study_sessions rows created by the 30/09/2026 live verification of D-46
-- Description: TestOutlook (26507dc7-5ceb-4940-878e-f4cdd2f6eab3) test rows only. The app cannot delete these (no
--   client DELETE), so this runs in the SQL editor. Aborts unless exactly these three ids are found for that user.
--     043a16ea-b708-4203-83f0-17658d1ba10d  practice_mode 84 s   (real save via End session & log time)
--     8b7ea15c-519a-4285-a788-017c3fdfb0e4  study_mode 660 s     (planted interrupted session, recovered)
--     f405e609-7b48-4775-be11-afabdf47c5f3  practice_mode 19 s   (Exit Practice)
--   Safe to re-run: if they are already gone it changes nothing.

DO $c$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM public.study_sessions
   WHERE user_id = '26507dc7-5ceb-4940-878e-f4cdd2f6eab3'
     AND id IN ('043a16ea-b708-4203-83f0-17658d1ba10d', '8b7ea15c-519a-4285-a788-017c3fdfb0e4', 'f405e609-7b48-4775-be11-afabdf47c5f3');
  IF n = 0 THEN
    RAISE NOTICE 'Already removed. Nothing changed.';
    RETURN;
  END IF;
  IF n <> 3 THEN
    RAISE EXCEPTION 'ABORT: expected exactly 3 test rows, found %. Nothing changed.', n;
  END IF;
  DELETE FROM public.study_sessions
   WHERE user_id = '26507dc7-5ceb-4940-878e-f4cdd2f6eab3'
     AND id IN ('043a16ea-b708-4203-83f0-17658d1ba10d', '8b7ea15c-519a-4285-a788-017c3fdfb0e4', 'f405e609-7b48-4775-be11-afabdf47c5f3');
  RAISE NOTICE 'Removed 3 test rows.';
END
$c$;
