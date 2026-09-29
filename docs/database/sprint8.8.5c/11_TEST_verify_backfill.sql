-- Name: [TEST] Sprint 8.8.5c - verify the backfill (read-only)
-- Description: Run AFTER 10. READ ONLY - no writes, no rollback needed. One result table.
--   V1  approved users have no active CA Foundation enrollment left (while their profile is CA Intermediate)
--   V2  archived rows = 1,903, all tagged 'CA Foundation', across 24 users
--   V3  Shriya Sundaram = 37 and Rujuta Bhatawadekar = 69 archived
--   V4  NOBODY excluded was touched: test accounts, ambiguous real users, professor, staff, NULL-course users
--       -> zero course_archived rows for all of them
--   V5  Paused review state preserved: Pareesa Joshi still has 30 archived rows with a 'suspended' review, Animesh 1
--   V6  no archived row belongs to a card whose course differs from its archived_course tag
--   Idempotency check (manual): note the V2 count, run 10 a second time, run this file again - V2 must be identical.

WITH approved(user_id) AS (VALUES
  ('9b91af8c-ec2a-4515-a9bf-7f6d51a3f647'::uuid),('7f0eede8-433a-463f-8a61-dcc95ca32f25'),('af76a1d9-2a54-44ac-a422-151977546f3c'),
  ('70c32f35-0a9a-4b6f-9f79-4b4c278db169'),('e34acf2c-883d-41fa-a0e3-1d4a6704725e'),('3d574eda-7d6a-4e34-a644-a2396ff79ffe'),
  ('11325130-19e1-4de5-9985-bdee2fbcb0bb'),('54a7261e-aab9-4b85-8007-d7439b83bf3b'),('eaacefdd-6c37-4132-99ee-0cce6a16a70b'),
  ('3d50aee0-73f4-40b1-a3a9-96de8b097556'),('030b9b9f-64a7-458b-a743-0b4b84d610a9'),('1de7a5d4-c780-4a5b-be53-47b95bb9e308'),
  ('d4dc60d2-66af-4caf-bbff-6b160665addd'),('c5bdb6d7-eeb0-4310-96de-24f6ba3929e5'),('2dfb5ca8-7cdd-4b4b-af8e-38006d0c79d1'),
  ('5f7bb1e1-e5ec-48ea-bc26-d20255d70b10'),('c920165b-01a4-4509-af9a-9440f83884f2'),('9bc8dcfa-6915-49a8-8dea-f5e73262caa6'),
  ('b8058121-d3c5-4500-8742-4ef2f14673aa'),('9a65df75-d528-44d7-8670-cfbd438c019e'),('44bbffe9-d961-4efc-98df-634ee11a7522'),
  ('2864316b-f842-4935-9e8d-83bb31d2553f'),('cd8bd383-88ba-4ad5-829a-7a94be9c4395'),('3e6ec4ed-b3fc-404c-ae30-de682733a28c')
),
excluded(user_id, why) AS (VALUES
  ('037a340d-6dd1-4cf4-8801-1f475ebea529'::uuid, 'test: Manish Sawant'),
  ('d2845195-ce98-4767-915c-78deb3a73187', 'test: Adhiraj Anand More'),
  ('26507dc7-5ceb-4940-878e-f4cdd2f6eab3', 'test: TestOutlook'),
  ('3a0062e1-e914-403b-b515-85a1dc6e1613', 'ambiguous: Aarya Santosh Kulkarni'),
  ('b4440313-5621-46bd-a9b2-7307dc01252f', 'ambiguous: Aaryaman More'),
  ('da84461a-2d45-4899-a8d4-da1f1c105b49', 'ambiguous: Anshul Tiwari'),
  ('075ad481-13e8-45e4-9deb-3c38907eb3e6', 'professor: CA Anand More'),
  ('82bc189a-d072-4952-a47f-73b045c8a3c4', 'staff: Anand More (super_admin)'),
  ('c80a9f56-fc73-4993-8acd-65a2330f1aa1', 'staff: Shailaja More (admin)')
)
SELECT 'V1 approved users: active Foundation enrollments left (profile still Intermediate)' AS check_name, '0' AS expected,
       COUNT(*)::text AS actual,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM public.my_cards_enrollment e
JOIN public.profiles pr ON pr.id = e.user_id AND pr.course_level = 'CA Intermediate'
JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE e.user_id IN (SELECT user_id FROM approved) AND e.status = 'active' AND f.target_course = 'CA Foundation'
UNION ALL
SELECT 'V2 archived rows / users (tag CA Foundation)', '1903 / 24',
       COUNT(*) || ' / ' || COUNT(DISTINCT e.user_id),
       CASE WHEN COUNT(*) = 1903 AND COUNT(DISTINCT e.user_id) = 24 THEN 'PASS' ELSE 'FAIL' END
FROM public.my_cards_enrollment e
WHERE e.status = 'course_archived' AND e.archived_course = 'CA Foundation'
UNION ALL
SELECT 'V3 Shriya (37) and Rujuta (69) archived', '37 / 69',
       COALESCE(SUM((e.user_id = 'c920165b-01a4-4509-af9a-9440f83884f2')::int), 0) || ' / ' ||
       COALESCE(SUM((e.user_id = 'd4dc60d2-66af-4caf-bbff-6b160665addd')::int), 0),
       CASE WHEN COALESCE(SUM((e.user_id = 'c920165b-01a4-4509-af9a-9440f83884f2')::int), 0) = 37
             AND COALESCE(SUM((e.user_id = 'd4dc60d2-66af-4caf-bbff-6b160665addd')::int), 0) = 69 THEN 'PASS' ELSE 'FAIL' END
FROM public.my_cards_enrollment e
WHERE e.status = 'course_archived' AND e.user_id IN ('c920165b-01a4-4509-af9a-9440f83884f2', 'd4dc60d2-66af-4caf-bbff-6b160665addd')
UNION ALL
SELECT 'V4 excluded accounts touched by the backfill (test, ambiguous, professor, staff)', '0',
       COUNT(*)::text, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM public.my_cards_enrollment e
WHERE e.status = 'course_archived' AND e.user_id IN (SELECT user_id FROM excluded)
UNION ALL
SELECT 'V4b NULL-course users touched', '0',
       COUNT(*)::text, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM public.my_cards_enrollment e JOIN public.profiles pr ON pr.id = e.user_id
WHERE e.status = 'course_archived' AND pr.course_level IS NULL
UNION ALL
SELECT 'V5 Paused review state preserved: Pareesa (30) / Animesh (1) archived rows with a suspended review', '30 / 1',
       COALESCE(SUM((e.user_id = 'b8058121-d3c5-4500-8742-4ef2f14673aa')::int), 0) || ' / ' ||
       COALESCE(SUM((e.user_id = '3e6ec4ed-b3fc-404c-ae30-de682733a28c')::int), 0),
       CASE WHEN COALESCE(SUM((e.user_id = 'b8058121-d3c5-4500-8742-4ef2f14673aa')::int), 0) = 30
             AND COALESCE(SUM((e.user_id = '3e6ec4ed-b3fc-404c-ae30-de682733a28c')::int), 0) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM public.my_cards_enrollment e
JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
WHERE e.status = 'course_archived' AND r.status = 'suspended'
  AND e.user_id IN ('b8058121-d3c5-4500-8742-4ef2f14673aa', '3e6ec4ed-b3fc-404c-ae30-de682733a28c')
UNION ALL
SELECT 'V6 archived rows whose card course differs from the archived_course tag', '0',
       COUNT(*)::text, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM public.my_cards_enrollment e JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE e.status = 'course_archived' AND f.target_course IS DISTINCT FROM e.archived_course;
