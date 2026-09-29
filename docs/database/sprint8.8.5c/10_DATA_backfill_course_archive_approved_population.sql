-- ============================================================================
-- Name: [DATA] Sprint 8.8.5c - one-time, idempotent course-archive of the APPROVED population
-- Description: Moves the stale CA Foundation enrollments of the 24 approved CA Intermediate students into the
--   'course_archived' state (tag archived_course = 'CA Foundation'), so they leave My Study / Review and return
--   automatically if a student ever switches back to CA Foundation. Shriya Sundaram (37) and Rujuta Bhatawadekar (69)
--   are included.
--   APPROVED POPULATION (operator approval, 30/09/2026): the 24 user ids below - the 23 clear Foundation->Intermediate
--   switchers from the 29/09 sweep plus Sairaj Kandhare (found by 02_DIAGNOSTIC block 3a) = 1,903 enrollments.
--   EXCLUDED on purpose: test accounts (Manish Sawant, Adhiraj Anand More, TestOutlook), the three ambiguous real
--   users (Aarya Santosh Kulkarni, Aaryaman More, Anshul Tiwari), the professor (CA Anand More) and staff.
--   PRECISE, NOT A BLANKET RULE: it acts only on these user ids AND only on rows that are role = student, profile
--   course = 'CA Intermediate', card course = 'CA Foundation', enrollment 'active', not a concept card.
--   `reviews` is never touched, so Paused (e.g. Pareesa Joshi's 30) and Mastered state are preserved.
--   SAFETY: the file first counts the rows it WOULD change. If that is not exactly 24 users / 1,903 rows it aborts and
--   changes nothing (population drifted since approval: re-run 02_DIAGNOSTIC 3a/3b and re-approve the new numbers).
--   IDEMPOTENT: once applied, the rule matches 0 rows and a re-run is a no-op.
--   ORDER: run only AFTER 03, 04, 05 are deployed and 08 has PASSED. Run on its own; do not add a ROLLBACK.
-- ============================================================================

DO $$
DECLARE
  v_approved uuid[] := ARRAY[
    '9b91af8c-ec2a-4515-a9bf-7f6d51a3f647', -- Jayesh Pande
    '7f0eede8-433a-463f-8a61-dcc95ca32f25', -- Shashwat Amit Randive
    'af76a1d9-2a54-44ac-a422-151977546f3c', -- Aayodh Inamke
    '70c32f35-0a9a-4b6f-9f79-4b4c278db169', -- Shardul Karnik
    'e34acf2c-883d-41fa-a0e3-1d4a6704725e', -- Sarang Gore
    '3d574eda-7d6a-4e34-a644-a2396ff79ffe', -- Chinmay Bhave
    '11325130-19e1-4de5-9985-bdee2fbcb0bb', -- Niranjan Jog
    '54a7261e-aab9-4b85-8007-d7439b83bf3b', -- Nihar Gokhale
    'eaacefdd-6c37-4132-99ee-0cce6a16a70b', -- Kashvi Kedia
    '3d50aee0-73f4-40b1-a3a9-96de8b097556', -- Neil Batavia
    '030b9b9f-64a7-458b-a743-0b4b84d610a9', -- Ira Bapat
    '1de7a5d4-c780-4a5b-be53-47b95bb9e308', -- Avantika Hagawane
    'd4dc60d2-66af-4caf-bbff-6b160665addd', -- Rujuta Bhatawadekar
    'c5bdb6d7-eeb0-4310-96de-24f6ba3929e5', -- Pratiksha Bhore
    '2dfb5ca8-7cdd-4b4b-af8e-38006d0c79d1', -- Atharva Deshpande
    '5f7bb1e1-e5ec-48ea-bc26-d20255d70b10', -- Aditya Karambelkar
    'c920165b-01a4-4509-af9a-9440f83884f2', -- Shriya Sundaram
    '9bc8dcfa-6915-49a8-8dea-f5e73262caa6', -- Priyanka Daroi
    'b8058121-d3c5-4500-8742-4ef2f14673aa', -- Pareesa Joshi
    '9a65df75-d528-44d7-8670-cfbd438c019e', -- Sairaj Kandhare
    '44bbffe9-d961-4efc-98df-634ee11a7522', -- Raghav Bhide
    '2864316b-f842-4935-9e8d-83bb31d2553f', -- Arnav Deshpande
    'cd8bd383-88ba-4ad5-829a-7a94be9c4395', -- Aaryan Ghate
    '3e6ec4ed-b3fc-404c-ae30-de682733a28c'  -- Animesh Khonde
  ]::uuid[];
  v_expected_users int := 24;
  v_expected_rows  int := 1903;
  v_users int; v_rows int; v_upd int;
BEGIN
  IF array_length(v_approved, 1) <> v_expected_users THEN
    RAISE EXCEPTION 'Approved id list has % entries, expected %', array_length(v_approved, 1), v_expected_users;
  END IF;

  SELECT COUNT(DISTINCT e.user_id), COUNT(*) INTO v_users, v_rows
  FROM public.my_cards_enrollment e
  JOIN public.profiles  pr ON pr.id = e.user_id
  JOIN public.flashcards f ON f.id = e.flashcard_id
  WHERE e.user_id = ANY (v_approved)
    AND e.status = 'active'
    AND pr.role = 'student' AND pr.course_level = 'CA Intermediate'
    AND f.target_course = 'CA Foundation' AND f.question_type <> 'concept_card';

  IF v_rows = 0 THEN
    RAISE NOTICE 'Nothing to do - already applied (idempotent no-op).';
    RETURN;
  END IF;

  IF v_users <> v_expected_users OR v_rows <> v_expected_rows THEN
    RAISE EXCEPTION 'Population changed since approval: expected % users / % enrollments, found % / %. NOTHING was changed. Re-run 02_DIAGNOSTIC blocks 3a/3b and approve the new numbers.',
      v_expected_users, v_expected_rows, v_users, v_rows;
  END IF;

  UPDATE public.my_cards_enrollment e
     SET status = 'course_archived', archived_course = 'CA Foundation', archived_at = now()
   WHERE e.id IN (
     SELECT e2.id
     FROM public.my_cards_enrollment e2
     JOIN public.profiles  pr ON pr.id = e2.user_id
     JOIN public.flashcards f ON f.id = e2.flashcard_id
     WHERE e2.user_id = ANY (v_approved)
       AND e2.status = 'active'
       AND pr.role = 'student' AND pr.course_level = 'CA Intermediate'
       AND f.target_course = 'CA Foundation' AND f.question_type <> 'concept_card');
  GET DIAGNOSTICS v_upd = ROW_COUNT;

  IF v_upd <> v_rows THEN
    RAISE EXCEPTION 'Updated % rows but expected %. Aborting (the whole statement rolls back).', v_upd, v_rows;
  END IF;
END $$;

-- Result (the SQL Editor shows only query results, not NOTICEs):
SELECT COUNT(DISTINCT e.user_id) AS users_with_archived_foundation_cards,
       COUNT(*)                   AS archived_enrollments
FROM public.my_cards_enrollment e
WHERE e.status = 'course_archived' AND e.archived_course = 'CA Foundation';
