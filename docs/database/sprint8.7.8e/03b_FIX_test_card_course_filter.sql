-- Name: [FIX] Clear target_course on 8.7.8e disposable test MCQ card
--
-- Description: Live-verification step, not the sprint fix itself. The test
-- card was created with target_course='CA Final', but the reviewing
-- professor's own profiles.course_level is a different course, so
-- get_study_queue's pre-existing, unchanged course-level gate (`p.course_level
-- IS NULL OR f.target_course IS NULL OR f.target_course = p.course_level`)
-- correctly filtered it out of their due queue — this is proof the gate
-- still works exactly as before, not a bug. The in-app course-context
-- switcher is confirmed session-display-only (its own label says so) and
-- does not affect profiles.course_level, so it can't be used to route around
-- this. Clearing target_course to NULL on just this one disposable row makes
-- it always pass the gate regardless of the reviewer's actual course_level,
-- without touching real data or the gate logic itself.

UPDATE public.flashcards
SET target_course = NULL
WHERE front_text LIKE '[8.7.8e TEST]%';

SELECT id, target_course, question_type, front_text
FROM public.flashcards
WHERE front_text LIKE '[8.7.8e TEST]%';
