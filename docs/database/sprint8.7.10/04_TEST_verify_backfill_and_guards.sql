-- Name: [TEST] Sprint 8.7.10 - verify backfill totals + get_my_cards/apply_review guards
-- Description: Post-deploy verification for 01_DATA, 02_FUNCTIONS, and 03_FUNCTIONS. Confirms:
-- backfill landed the expected 1187 rows with reviews untouched; suspended cards stay enrolled
-- (visible) but excluded from the due queue; get_my_cards now requires enrollment for own cards;
-- apply_review rejects a non-enrolled card and a suspended card.
--
-- Impersonates real profiles via request.jwt.claims + SET LOCAL ROLE authenticated (same idiom
-- as sprint7.5/02_TEST and sprint8.6c/03_TEST) -- the Supabase SQL Editor connection runs as a
-- superuser/owner role, so auth.uid() is NULL and get_my_cards/apply_review's own IDOR guards
-- ("Access denied: authentication required") would fire before ever reaching the new checks
-- unless the role is genuinely switched, not just the jwt claim set.
--
-- ALL writes are inside BEGIN...ROLLBACK -- nothing here is committed, safe to run repeatedly.
-- Run AFTER 01_DATA, 02_FUNCTIONS, and 03_FUNCTIONS are all committed.

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
CREATE TEMP TABLE _fx(k text PRIMARY KEY, v text);
GRANT SELECT, INSERT, UPDATE ON _r, _fx TO authenticated;

-- ══ 1. Backfill landed exactly the expected population, reviews untouched (no RLS involved) ══
DO $$
DECLARE v_total int; v_active int; v_suspended int;
BEGIN
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE r.status = 'active'),
    COUNT(*) FILTER (WHERE r.status = 'suspended')
  INTO v_total, v_active, v_suspended
  FROM public.my_cards_enrollment me
  JOIN public.flashcards f ON f.id = me.flashcard_id AND f.user_id = me.user_id
  JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
  WHERE me.status = 'active';

  INSERT INTO _r VALUES ('backfill total = 1187 [CRITICAL]', '1187', v_total::text,
    CASE WHEN v_total = 1187 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('backfill active-review split = 908', '908', v_active::text,
    CASE WHEN v_active = 908 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('backfill suspended-review split = 279', '279', v_suspended::text,
    CASE WHEN v_suspended = 279 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ Fixtures: pick one real user with a suspended own card, and one with a never-reviewed
--    own card, from the live population (no RLS involved — plain SELECT as connecting role) ══
DO $$
DECLARE v_suspended_user uuid; v_suspended_card uuid;
         v_unreviewed_user uuid; v_unreviewed_card uuid;
BEGIN
  SELECT r.user_id, r.flashcard_id INTO v_suspended_user, v_suspended_card
  FROM public.reviews r
  JOIN public.flashcards f ON f.id = r.flashcard_id AND f.user_id = r.user_id
  WHERE r.status = 'suspended' LIMIT 1;

  SELECT f.user_id, f.id INTO v_unreviewed_user, v_unreviewed_card
  FROM public.flashcards f
  WHERE f.question_type IS DISTINCT FROM 'concept_card'
    AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.flashcard_id = f.id AND r.user_id = f.user_id)
    AND NOT EXISTS (SELECT 1 FROM public.my_cards_enrollment me WHERE me.flashcard_id = f.id AND me.user_id = f.user_id)
  LIMIT 1;

  IF v_suspended_card IS NOT NULL THEN
    INSERT INTO _fx VALUES ('susp_user', v_suspended_user::text), ('susp_card', v_suspended_card::text);
  END IF;
  IF v_unreviewed_card IS NOT NULL THEN
    INSERT INTO _fx VALUES ('unrev_user', v_unreviewed_user::text), ('unrev_card', v_unreviewed_card::text);
  END IF;
END $$;

-- ══ 2. get_my_cards, impersonated as the suspended-card owner: card still visible (enrollment
--    membership preserved through the backfill) ══════════════════════════════════════════════
DO $$
DECLARE v_user uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'susp_user') THEN RETURN; END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'susp_user';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_user uuid; v_card uuid; v_found boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'susp_user') THEN
    INSERT INTO _r VALUES ('suspended card still in get_my_cards', 'true', 'no suspended fixture found', 'SKIP');
    RETURN;
  END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'susp_user';
  SELECT v::uuid INTO v_card FROM _fx WHERE k = 'susp_card';
  SELECT EXISTS (SELECT 1 FROM public.get_my_cards(v_user) g WHERE g.id = v_card) INTO v_found;
  INSERT INTO _r VALUES ('suspended card still in get_my_cards [membership preserved]', 'true', v_found::text,
    CASE WHEN v_found THEN 'PASS' ELSE 'FAIL' END);
END $$;

RESET ROLE;

-- ══ 3. Suspended cards excluded from get_study_queue (unchanged function, confirming the
--    interaction still holds post-migration; no RLS involved) ═══════════════════════════════
DO $$
DECLARE v_wrongly_due int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'susp_user') THEN
    INSERT INTO _r VALUES ('suspended cards excluded from due queue', '0', 'no suspended fixture found', 'SKIP');
    RETURN;
  END IF;
  SELECT COUNT(*) INTO v_wrongly_due
  FROM public.reviews r
  WHERE r.status = 'suspended'
    AND r.flashcard_id IN (SELECT flashcard_id FROM public.get_study_queue(r.user_id));
  INSERT INTO _r VALUES ('suspended cards excluded from due queue [CRITICAL]', '0', v_wrongly_due::text,
    CASE WHEN v_wrongly_due = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ 4. get_my_cards, impersonated as the never-reviewed-own-card owner: card must NOT appear
--    (own cards now require enrollment, same as external) ════════════════════════════════════
DO $$
DECLARE v_user uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'unrev_user') THEN RETURN; END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'unrev_user';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_user uuid; v_card uuid; v_found boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'unrev_user') THEN
    INSERT INTO _r VALUES ('never-reviewed own card excluded from get_my_cards', 'false', 'no unreviewed fixture found', 'SKIP');
    RETURN;
  END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'unrev_user';
  SELECT v::uuid INTO v_card FROM _fx WHERE k = 'unrev_card';
  SELECT EXISTS (SELECT 1 FROM public.get_my_cards(v_user) g WHERE g.id = v_card) INTO v_found;
  INSERT INTO _r VALUES ('never-reviewed own card excluded from get_my_cards [CRITICAL]', 'false', v_found::text,
    CASE WHEN NOT v_found THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ 5. apply_review rejects grading that same never-reviewed, non-enrolled own card ══════════
DO $$
DECLARE v_user uuid; v_card uuid; v_err text; v_code text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'unrev_user') THEN
    INSERT INTO _r VALUES ('apply_review rejects non-enrolled card', '42501', 'no unreviewed fixture found', 'SKIP');
    RETURN;
  END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'unrev_user';
  SELECT v::uuid INTO v_card FROM _fx WHERE k = 'unrev_card';
  BEGIN
    PERFORM public.apply_review(v_user, v_card, 'easy');
    INSERT INTO _r VALUES ('apply_review rejects non-enrolled card [CRITICAL]', '42501 raised', 'no error raised', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_code = RETURNED_SQLSTATE, v_err = MESSAGE_TEXT;
    INSERT INTO _r VALUES ('apply_review rejects non-enrolled card [CRITICAL]', '42501', v_code || ': ' || v_err,
      CASE WHEN v_code = '42501' THEN 'PASS' ELSE 'FAIL' END);
  END;
END $$;

RESET ROLE;

-- ══ 6. apply_review rejects grading a suspended (but enrolled) card ══════════════════════════
DO $$
DECLARE v_user uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'susp_user') THEN RETURN; END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'susp_user';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_user uuid; v_card uuid; v_err text; v_code text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'susp_user') THEN
    INSERT INTO _r VALUES ('apply_review rejects suspended card', '42501', 'no suspended fixture found', 'SKIP');
    RETURN;
  END IF;
  SELECT v::uuid INTO v_user FROM _fx WHERE k = 'susp_user';
  SELECT v::uuid INTO v_card FROM _fx WHERE k = 'susp_card';
  BEGIN
    PERFORM public.apply_review(v_user, v_card, 'easy');
    INSERT INTO _r VALUES ('apply_review rejects suspended card [CRITICAL]', '42501 raised', 'no error raised', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_code = RETURNED_SQLSTATE, v_err = MESSAGE_TEXT;
    INSERT INTO _r VALUES ('apply_review rejects suspended card [CRITICAL]', '42501', v_code || ': ' || v_err,
      CASE WHEN v_code = '42501' THEN 'PASS' ELSE 'FAIL' END);
  END;
END $$;

RESET ROLE;

-- ══ Results ═══════════════════════════════════════════════════════════════════════════════
SELECT * FROM _r ORDER BY check_name;

ROLLBACK;
-- ROLLBACK guarantees zero side effects from this entire verification run either way.
