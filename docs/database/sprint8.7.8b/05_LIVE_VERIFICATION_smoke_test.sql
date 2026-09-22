-- Name: [TEST] Live disposable-data smoke verification — Sprint 8.7.8b (NOT wrapped in ROLLBACK)
--
-- Description: Deployment-order step 10. Unlike 03_TEST (which runs entirely inside BEGIN...ROLLBACK
-- and never touches live data), this script COMMITS real rows through the real RPC surface, using
-- two existing real student profiles and one disposable flashcard, then a companion cleanup block
-- (run second, separately) removes every row this script created. Run block A, inspect the output,
-- confirm it matches the expected column, then run block B (cleanup) and confirm the final query
-- returns zero rows before moving on.
--
-- Do NOT run this inside the same transaction as 03_TEST or any DDL file (L3 17c lesson).

-- ═══════════════════════════════ BLOCK A — live round-trip ═══════════════════════════════
DO $$
DECLARE
  v_a uuid; v_b uuid; v_course text; v_card uuid;
BEGIN
  SELECT id INTO v_a FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_b FROM public.profiles WHERE role = 'student' AND id <> v_a LIMIT 1;
  SELECT target_course INTO v_course FROM public.flashcards WHERE target_course IS NOT NULL LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'Need 2 real student profiles to run this smoke test';
  END IF;

  INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility, question_type)
  VALUES (v_b, v_course, '8.7.8b LIVE SMOKE TEST — safe to delete', 'back', 'public', 'mcq')
  RETURNING id INTO v_card;

  UPDATE public.flashcards
    SET options = '["opt0","opt1"]'::jsonb, correct_answer = '0'
  WHERE id = v_card;

  -- Impersonate v_a for the RPC calls that require auth.uid() = p_user_id.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- add visible external card
  PERFORM public.add_to_my_cards(v_a, v_card);
  -- double-add (idempotent)
  PERFORM public.add_to_my_cards(v_a, v_card);
  -- practice attempt, no SRS side effect
  PERFORM public.log_practice_attempt(v_a, v_card, true);
  -- remove before first grade
  PERFORM public.remove_from_my_cards(v_a, v_card);
  -- add -> genuine review -> remove
  PERFORM public.add_to_my_cards(v_a, v_card);
  INSERT INTO public.reviews (user_id, flashcard_id, quality, interval, repetition, easiness, rung, next_review_date, status)
  VALUES (v_a, v_card, 5, 3, 1, 2.6, 2, CURRENT_DATE + 3, 'active')
  ON CONFLICT (user_id, flashcard_id) DO UPDATE SET quality=5, interval=3, repetition=1, easiness=2.6, rung=2, next_review_date=CURRENT_DATE+3, status='active';
  PERFORM public.remove_from_my_cards(v_a, v_card);
  -- re-add: preserves prior SRS progress
  PERFORM public.add_to_my_cards(v_a, v_card);

  -- Deliberately NOT resetting jwt claims here — the get_my_cards inspection query below needs
  -- to run impersonating this same v_a (profiles WHERE role='student' LIMIT 1, same deterministic
  -- row) so its own IDOR guard passes. Reset happens after that query, at the end of this file.

  RAISE NOTICE 'Smoke test complete. v_card = %, v_a = %', v_card, v_a;
END $$;

-- Inspect: expect enrollment status='active', reviews status='active' with rung=2/repetition=1/
-- easiness=2.6 preserved, and exactly ONE practice_attempts row (is_correct=true) for this card.
SELECT 'enrollment' AS what, e.status, e.added_at
FROM public.my_cards_enrollment e
JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE f.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';

SELECT 'reviews' AS what, r.status, r.rung, r.repetition, r.easiness, r.next_review_date
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';

SELECT 'practice_attempts' AS what, pa.is_correct, pa.attempted_at
FROM public.practice_attempts pa
JOIN public.flashcards f ON f.id = pa.flashcard_id
WHERE f.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';

-- get_my_cards includes it — still impersonating v_a (jwt claims left set from Block A's DO block
-- on purpose; this call needs p_user_id = auth.uid() = v_a to pass its own IDOR guard).
SELECT 'get_my_cards' AS what, gmc.id, gmc.front_text
FROM public.get_my_cards((SELECT id FROM public.profiles WHERE role = 'student' LIMIT 1)) gmc
WHERE gmc.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';

-- Reset impersonation now that every guarded call in this script is done.
SELECT set_config('request.jwt.claims', NULL, true);

-- ═══════════════════════════════ BLOCK B — cleanup (run after inspecting the above) ═══════════════════════════════
-- Uncomment and run once you've confirmed the inspection queries above look correct.

-- DELETE FROM public.practice_attempts pa
--   USING public.flashcards f
--   WHERE pa.flashcard_id = f.id AND f.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';
--
-- DELETE FROM public.reviews r
--   USING public.flashcards f
--   WHERE r.flashcard_id = f.id AND f.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';
--
-- DELETE FROM public.my_cards_enrollment e
--   USING public.flashcards f
--   WHERE e.flashcard_id = f.id AND f.front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';
--
-- DELETE FROM public.flashcards WHERE front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';

-- ═══════════════════════════════ CONFIRM NO RESIDUE (run last) ═══════════════════════════════
-- SELECT count(*) AS residue FROM public.flashcards WHERE front_text = '8.7.8b LIVE SMOKE TEST — safe to delete';
-- Expect residue = 0. The CASCADE FKs on my_cards_enrollment/practice_attempts/reviews mean
-- deleting the flashcards row alone would also be sufficient, but the explicit deletes above are
-- included so you can inspect each table's row before it's gone.
