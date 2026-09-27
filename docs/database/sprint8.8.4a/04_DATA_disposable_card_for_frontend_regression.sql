-- Name: [DATA] Sprint 8.8.4a - disposable un-enrolled card, Part D frontend regression test only
-- Description: Creates ONE throwaway flashcard + reviews row for the currently-logged-in browser
-- session (075ad481-13e8-45e4-9deb-3c38907eb3e6), due today, deliberately WITHOUT a
-- my_cards_enrollment row. This reproduces the exact server rejection apply_review's Sprint 8.7.10
-- guard raises (42501 "Card is not enrolled in My Study") for testing StudyMode.jsx's Sprint
-- 8.8.4a fix live: the "Retry Save" UI should appear instead of silently advancing.
--
-- This card will show up in the Review flow via get_study_queue (which never checked enrollment
-- -- that's the whole root cause) despite having no enrollment row -- reproducing production
-- behavior exactly.
--
-- DELETE it immediately after the browser test using 05_CLEANUP_disposable_card.sql. Do not leave
-- this row in production data.

WITH new_card AS (
  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, question_type, visibility)
  VALUES (
    '075ad481-13e8-45e4-9deb-3c38907eb3e6',
    'CA Intermediate',
    'ZZ_TEST_8.8.4a_PARTD — disposable, delete immediately after this session''s browser test',
    'disposable test answer — Sprint 8.8.4a frontend regression only',
    'flashcard',
    'private'
  )
  RETURNING id
)
INSERT INTO public.reviews (
  user_id, flashcard_id, quality, "interval", repetition, easiness,
  next_review_date, last_reviewed_at, status, rung
)
SELECT
  '075ad481-13e8-45e4-9deb-3c38907eb3e6', id, 3, 1, 1, 2.5,
  CURRENT_DATE, now(), 'active', 1
FROM new_card
RETURNING flashcard_id;

-- Note the returned flashcard_id if you want it, but the card is also identifiable in the app by
-- its front_text ("ZZ_TEST_8.8.4a_PARTD..."). No my_cards_enrollment row is inserted for it --
-- that omission is the point.
