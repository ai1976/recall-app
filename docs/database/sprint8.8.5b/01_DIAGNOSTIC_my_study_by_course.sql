-- ============================================================================
-- Name: [DIAGNOSTIC] My Study enrolled cards by course/discipline (items 2 + 4) — READ ONLY
-- Description: Re-run of the two queries from 00_ that failed (subjects has no
--   course_level column; it links to a course via discipline_id -> disciplines).
--   Shows which course each active enrolled card belongs to, for Shriya and Rujuta.
-- ============================================================================

-- Shriya Sundardm (c920165b-...)
SELECT COALESCE(d.name, 'no discipline') AS course, COALESCE(s.name, f.custom_subject, 'Other') AS subject, COUNT(*) AS n
FROM my_cards_enrollment e
JOIN flashcards f ON f.id = e.flashcard_id
LEFT JOIN subjects s ON s.id = f.subject_id
LEFT JOIN disciplines d ON d.id = s.discipline_id
WHERE e.user_id = 'c920165b-01a4-4509-af9a-9440f83884f2' AND e.status = 'active'
GROUP BY 1, 2 ORDER BY n DESC;

-- Rujuta Bhatwadekar (d4dc60d2-...)
SELECT COALESCE(d.name, 'no discipline') AS course, COALESCE(s.name, f.custom_subject, 'Other') AS subject, COUNT(*) AS n
FROM my_cards_enrollment e
JOIN flashcards f ON f.id = e.flashcard_id
LEFT JOIN subjects s ON s.id = f.subject_id
LEFT JOIN disciplines d ON d.id = s.discipline_id
WHERE e.user_id = 'd4dc60d2-66af-4caf-bbff-6b160665addd' AND e.status = 'active'
GROUP BY 1, 2 ORDER BY n DESC;
