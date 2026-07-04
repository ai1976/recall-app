-- Name: [TEST] Verify deck listing + activity feed hide zero-visible decks
-- Description: Post-deploy verification for 05_FUNCTIONS (get_browsable_decks v4) and 06_FUNCTIONS
-- (get_recent_activity_feed). Uses the real reported deck 1e521de5 (public shell, 1 private card, 0
-- public) and real users: asserts a non-owner professor no longer sees it in either surface, while
-- the OWNER still sees it (with the correct owner-visible count). Read-only; BEGIN...ROLLBACK.
-- get_browsable_decks is SECURITY DEFINER + reads auth.uid(), so we impersonate via
-- set_config('request.jwt.claims', ...). NOTE: the activity-feed check is time-sensitive — the deck
-- must still be within the feed's 7-day window; if 1e521de5 is older, that row reports SKIP.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_deck   uuid := '1e521de5-473b-4bec-9f9e-c0d40834e7f2';
  v_owner  uuid;
  v_course text;
  v_created timestamptz;
  v_prof   uuid;
  v_n      int;
  v_cc     int;
  v_owner_visible int;
BEGIN
  SELECT user_id, target_course, created_at INTO v_owner, v_course, v_created
  FROM public.flashcard_decks WHERE id = v_deck;

  IF v_owner IS NULL THEN
    INSERT INTO _r VALUES ('fixture deck', 'exists', 'missing', 'SKIP: deck 1e521de5 not found');
    RETURN;
  END IF;

  -- A professor who is NOT the owner and NOT an admin (course gate bypassed, no card override).
  SELECT id INTO v_prof
  FROM public.profiles
  WHERE role = 'professor' AND id <> v_owner
  LIMIT 1;

  -- Owner-visible card count for this deck (what the owner should see as card_count).
  SELECT count(*) INTO v_owner_visible
  FROM public.flashcards fc
  WHERE fc.user_id = v_owner
    AND fc.subject_id IS NOT DISTINCT FROM (SELECT subject_id FROM flashcard_decks WHERE id=v_deck)
    AND fc.topic_id   IS NOT DISTINCT FROM (SELECT topic_id   FROM flashcard_decks WHERE id=v_deck)
    AND fc.custom_subject IS NOT DISTINCT FROM (SELECT custom_subject FROM flashcard_decks WHERE id=v_deck)
    AND fc.custom_topic   IS NOT DISTINCT FROM (SELECT custom_topic   FROM flashcard_decks WHERE id=v_deck);

  -- ---- get_browsable_decks as a NON-OWNER PROFESSOR: deck must be ABSENT ----
  IF v_prof IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM get_browsable_decks() WHERE id = v_deck;
    INSERT INTO _r VALUES ('browsable_decks: non-owner prof sees deck [CRITICAL]', '0', v_n::text,
      CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL: zero-visible-card deck still listed' END);
  ELSE
    INSERT INTO _r VALUES ('browsable_decks: non-owner prof', 'a professor', 'none',
      'SKIP: no non-owner professor fixture');
  END IF;

  -- ---- get_browsable_decks as the OWNER: deck PRESENT with owner-visible count ----
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  SELECT count(*), max(card_count) INTO v_n, v_cc FROM get_browsable_decks() WHERE id = v_deck;
  INSERT INTO _r VALUES ('browsable_decks: owner still sees own deck', '1', v_n::text,
    CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL: owner lost their own deck' END);
  INSERT INTO _r VALUES ('browsable_decks: owner card_count = owner-visible', v_owner_visible::text,
    COALESCE(v_cc::text,'null'),
    CASE WHEN v_cc = v_owner_visible THEN 'PASS' ELSE 'FAIL: wrong owner count' END);

  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ---- get_recent_activity_feed for the non-owner professor: deck must be ABSENT ----
  IF v_prof IS NULL THEN
    INSERT INTO _r VALUES ('activity_feed: deck present', 'skipped', 'n/a', 'SKIP: no professor fixture');
  ELSIF v_created < NOW() - INTERVAL '7 days' THEN
    INSERT INTO _r VALUES ('activity_feed: deck present', 'skipped', 'deck older than 7d',
      'SKIP: deck outside feed window (time-sensitive)');
  ELSE
    -- Pass the deck's own course so the course filter passes; the ONLY reason to exclude is the new
    -- zero-visible-card EXISTS.
    SELECT count(*) INTO v_n
    FROM get_recent_activity_feed(v_prof, v_course, 50)
    WHERE creator_id = v_owner AND content_type = 'flashcard_deck';
    INSERT INTO _r VALUES ('activity_feed: non-owner sees deck [CRITICAL]', '0', v_n::text,
      CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL: zero-visible-card deck still in feed' END);
  END IF;
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
