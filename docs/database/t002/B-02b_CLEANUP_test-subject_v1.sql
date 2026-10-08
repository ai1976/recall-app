-- Name: [CLEANUP] T-002 B-02b acceptance test - remove the test subject and its two topics (v1)
--
-- Description: DATA change, run ONCE as one selection after the B-02b live acceptance upload of 08/10/2026 (admin upload through BulkUploadTopics under CA Final created
-- 1 subject "ZZ Test Subject 08-10" and 2 topics "ZZ Test Topic 1", "ZZ Test Topic 2"). It deletes exactly those rows and aborts (changing nothing) unless it finds exactly
-- 1 such subject under CA Final, exactly 2 topics under it, and no other topic under it. Not a Tier 1 platform change: it removes only the Founder's own test rows.
-- Expected result: one row, remaining_subjects 0, remaining_topics 0.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $cleanup$
DECLARE
  v_sid uuid;
  v_subjects int;
  v_topics int;
  v_all_topics int;
BEGIN
  SELECT count(*) INTO v_subjects
    FROM public.subjects s JOIN public.disciplines d ON d.id = s.discipline_id
   WHERE s.name = 'ZZ Test Subject 08-10' AND d.name = 'CA Final';
  IF v_subjects <> 1 THEN
    RAISE EXCEPTION 'cleanup stopped: expected exactly 1 test subject under CA Final, found %', v_subjects;
  END IF;
  SELECT s.id INTO v_sid
    FROM public.subjects s JOIN public.disciplines d ON d.id = s.discipline_id
   WHERE s.name = 'ZZ Test Subject 08-10' AND d.name = 'CA Final';
  SELECT count(*) INTO v_all_topics FROM public.topics WHERE subject_id = v_sid;
  SELECT count(*) INTO v_topics FROM public.topics
   WHERE subject_id = v_sid AND name IN ('ZZ Test Topic 1', 'ZZ Test Topic 2');
  IF v_all_topics <> 2 OR v_topics <> 2 THEN
    RAISE EXCEPTION 'cleanup stopped: expected exactly the 2 test topics under the test subject, found % in total, % matching', v_all_topics, v_topics;
  END IF;
  DELETE FROM public.topics WHERE subject_id = v_sid;
  DELETE FROM public.subjects WHERE id = v_sid;
END
$cleanup$;

SELECT
  (SELECT count(*) FROM public.subjects WHERE name = 'ZZ Test Subject 08-10') AS remaining_subjects,
  (SELECT count(*) FROM public.topics WHERE name IN ('ZZ Test Topic 1', 'ZZ Test Topic 2')) AS remaining_topics;
