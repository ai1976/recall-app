-- Name: [TEST] Verify profiles cascade + attribution SET NULL (L4)
-- Description: Post-deploy verification for 20_SCHEMA. Two parts:
--   Block 1 (deterministic gate) — asserts the 9 FK ON DELETE actions are exactly as intended.
--     An FK's ON DELETE action is enforced by Postgres itself, so this metadata check IS proof the
--     delete behavior is correct; it is the PASS/FAIL gate.
--   Block 2 (best-effort live delete) — fabricates a throwaway auth.users row (which fires the
--     profile-creation trigger), attaches it as an attribution (creator_id) on a flashcard owned by
--     a DIFFERENT real user, deletes the auth.users row, and confirms: the profile cascaded away AND
--     the other user's flashcard survived with creator_id nulled. Guarded — if the auth.users
--     fixture can't be created in this environment, it records SKIP rather than failing the sprint.
-- Row-returning verdict; whole thing wrapped in BEGIN...ROLLBACK (nothing persists).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

-- ============================================
-- BLOCK 1 — constraint actions (the gate). Expect: profiles = CASCADE; the 8 attribution = SET NULL.
-- ============================================
DO $$
DECLARE
  r RECORD;
  v_act text;
  v_exp text;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('profiles',        'profiles_id_fkey',                             'CASCADE'),
      ('notes',           'notes_contributed_by_fkey',                    'SET NULL'),
      ('notes',           'notes_featured_approved_by_fkey',              'SET NULL'),
      ('notes',           'notes_featured_nominated_by_fkey',             'SET NULL'),
      ('flashcards',      'flashcards_contributed_by_fkey',               'SET NULL'),
      ('flashcards',      'flashcards_creator_id_fkey',                   'SET NULL'),
      ('flashcard_decks', 'flashcard_decks_featured_approved_by_fkey',    'SET NULL'),
      ('flashcard_decks', 'flashcard_decks_featured_nominated_by_fkey',   'SET NULL'),
      ('content_flags',   'content_flags_resolved_by_fkey',               'SET NULL')
    ) AS t(tbl, conname, expected)
  LOOP
    SELECT CASE confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
             WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END
      INTO v_act
    FROM pg_constraint
    WHERE conname = r.conname AND conrelid = ('public.' || r.tbl)::regclass;

    v_exp := r.expected;
    INSERT INTO _r VALUES ('fk ' || r.tbl || '.' || r.conname, v_exp, COALESCE(v_act, 'MISSING'),
      CASE WHEN v_act = v_exp THEN 'PASS' ELSE 'FAIL' END);
  END LOOP;
END $$;

-- ============================================
-- BLOCK 2 — best-effort live delete (fabricated user). SKIP on any fixture error.
-- ============================================
DO $$
DECLARE
  v_uid    uuid := gen_random_uuid();
  v_email  text := 'l4test_' || replace(v_uid::text, '-', '') || '@example.com';
  v_owner  uuid;
  v_card   uuid;
  v_profile_exists boolean;
  v_card_exists    boolean;
  v_creator_null   boolean;
BEGIN
  -- A real, existing owner for the content (not our throwaway user).
  SELECT id INTO v_owner FROM public.profiles LIMIT 1;

  BEGIN
    -- Fabricate an auth.users row; the signup trigger auto-creates its profiles row.
    INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at,
                            raw_app_meta_data, raw_user_meta_data, email_confirmed_at)
    VALUES (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', v_email,
            now(), now(), '{"provider":"email"}'::jsonb,
            jsonb_build_object('full_name','L4 Cascade Test'), now());
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('live delete cascade', 'skipped', SQLERRM,
      'SKIP: could not fabricate auth.users in this env (' || left(SQLERRM, 60) || ')');
    RETURN;
  END;

  -- Attribution on ANOTHER user's flashcard: creator_id = throwaway user, owner = real user.
  INSERT INTO public.flashcards
    (user_id, contributed_by, creator_id, target_course, front_text, back_text, visibility, is_verified, difficulty, batch_id)
  VALUES
    (v_owner, NULL, v_uid, 'test_course', '_L4TEST_attribution_card', 'x', 'private', false, 'medium', gen_random_uuid())
  RETURNING id INTO v_card;

  -- Delete the auth.users row — the whole point.
  DELETE FROM auth.users WHERE id = v_uid;

  SELECT EXISTS(SELECT 1 FROM public.profiles   WHERE id = v_uid)               INTO v_profile_exists;
  SELECT EXISTS(SELECT 1 FROM public.flashcards WHERE id = v_card)              INTO v_card_exists;
  SELECT creator_id IS NULL           FROM public.flashcards WHERE id = v_card  INTO v_creator_null;

  INSERT INTO _r VALUES ('profile cascaded on user delete', 'false (gone)', v_profile_exists::text,
    CASE WHEN v_profile_exists = false THEN 'PASS' ELSE 'FAIL: profile survived' END);
  INSERT INTO _r VALUES ('other user''s card preserved', 'true', v_card_exists::text,
    CASE WHEN v_card_exists THEN 'PASS' ELSE 'FAIL: cascade wrongly deleted another user''s card' END);
  INSERT INTO _r VALUES ('attribution set null [CRITICAL]', 'true', COALESCE(v_creator_null::text,'n/a'),
    CASE WHEN v_creator_null THEN 'PASS' ELSE 'FAIL: creator_id not nulled' END);
END $$;

-- Single result set, failures first.
SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;

ROLLBACK;
