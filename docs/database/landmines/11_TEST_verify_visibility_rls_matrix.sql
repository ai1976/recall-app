-- Name: [TEST] Verify notes/flashcards visibility RLS matrix
-- Description: Exhaustive read-access matrix for the L2 is_public -> visibility RLS
-- rewrite (10_SCHEMA). Covers {owner, accepted-friend, non-friend authenticated, anon} x
-- {public, friends, private} for both notes and flashcards. Run in full immediately after
-- deploying 10_SCHEMA. Every row must say PASS — if any "stranger" or "anon" row against
-- friends/private content is not PASS, STOP: that is a live private-content exposure.
--
-- Self-contained and non-destructive: everything happens inside one BEGIN/ROLLBACK. Fixture
-- rows are tagged with a `_L2TEST_` prefix and nothing is committed. The SQL Editor runs as
-- `postgres`, which bypasses RLS entirely — so each check explicitly SET LOCAL ROLEs to
-- `authenticated` or `anon` and sets `request.jwt.claims` to impersonate a specific user,
-- the same technique PostgREST itself uses.
--
-- Re-running after Stage B (12_SCHEMA drops is_public): the two fixture INSERT statements
-- below still set `is_public` explicitly (harmless while the column exists, and it makes the
-- fixture match real pre-migration data shape). Once 12_SCHEMA has run, is_public no longer
-- exists — remove `, is_public` from both column lists and `, true`/`, false` from the
-- corresponding VALUES before re-running this file. (13_TEST covers the "insert succeeds
-- without is_public" case separately and does not need this edit.)
--
-- Depends on friendships' own RLS ("users manage own friendships" — a party can SELECT rows
-- where they are user_id or friend_id) to let the "friend" actor see their own accepted
-- friendship row when 10_SCHEMA's EXISTS subquery runs as that actor. If friendships RLS is
-- ever tightened, re-verify this assumption.

BEGIN;

-- ============================================
-- Fixtures: 3 distinct real profiles (no auth.users fabrication needed — see L1 06_TEST
-- precedent for why this is safer than fabricating auth rows)
-- ============================================
CREATE TEMP TABLE _fixture(role_label text PRIMARY KEY, id uuid NOT NULL);
GRANT SELECT ON _fixture TO authenticated, anon;

CREATE TEMP TABLE _r(cell text, expected text, actual_count text, verdict text);
GRANT SELECT, INSERT ON _r TO authenticated, anon;

DO $$
DECLARE v_count int;
BEGIN
  INSERT INTO _fixture SELECT 'owner', id FROM public.profiles ORDER BY created_at LIMIT 1 OFFSET 0;
  INSERT INTO _fixture SELECT 'friend', id FROM public.profiles ORDER BY created_at LIMIT 1 OFFSET 1;
  INSERT INTO _fixture SELECT 'stranger', id FROM public.profiles ORDER BY created_at LIMIT 1 OFFSET 2;
  SELECT count(*) INTO v_count FROM _fixture;
  IF v_count < 3 THEN
    RAISE EXCEPTION 'Need at least 3 distinct profiles to run this matrix — found %', v_count;
  END IF;
END $$;

-- Deterministic friendship state: wipe any pre-existing rows between the fixture pairs,
-- then create exactly one accepted friendship (owner <-> friend). owner <-> stranger stays
-- friendship-free on purpose.
DELETE FROM public.friendships f
USING _fixture o, _fixture x
WHERE o.role_label = 'owner' AND x.role_label IN ('friend', 'stranger')
  AND ((f.user_id = o.id AND f.friend_id = x.id) OR (f.user_id = x.id AND f.friend_id = o.id));

INSERT INTO public.friendships (user_id, friend_id, status)
SELECT o.id, f.id, 'accepted' FROM _fixture o, _fixture f
WHERE o.role_label = 'owner' AND f.role_label = 'friend';

-- Fixture content, one row per visibility tier, all owned by "owner". Tagged titles/front_text
-- so assertions can target them precisely regardless of what else exists in the live table.
-- content_type is CHECK-constrained (rejects arbitrary literals like 'Text'); source a valid
-- value from an existing note rather than guessing the allowed set.
INSERT INTO public.notes (user_id, title, content_type, target_course, visibility, is_public)
SELECT id, '_L2TEST_note_public',  (SELECT content_type FROM public.notes WHERE content_type IS NOT NULL LIMIT 1), 'test_course', 'public',  true  FROM _fixture WHERE role_label = 'owner'
UNION ALL
SELECT id, '_L2TEST_note_friends', (SELECT content_type FROM public.notes WHERE content_type IS NOT NULL LIMIT 1), 'test_course', 'friends', false FROM _fixture WHERE role_label = 'owner'
UNION ALL
SELECT id, '_L2TEST_note_private', (SELECT content_type FROM public.notes WHERE content_type IS NOT NULL LIMIT 1), 'test_course', 'private', false FROM _fixture WHERE role_label = 'owner';

-- Match the L1 06_TEST proven-good flashcards insert shape (contributed_by/creator_id/
-- is_verified/difficulty/batch_id) so no NOT NULL/CHECK column is missed.
INSERT INTO public.flashcards (user_id, contributed_by, creator_id, target_course, front_text, back_text, visibility, is_public, is_verified, difficulty, batch_id)
SELECT id, id, id, 'test_course', '_L2TEST_card_public',  'x', 'public',  true,  false, 'medium', gen_random_uuid() FROM _fixture WHERE role_label = 'owner'
UNION ALL
SELECT id, id, id, 'test_course', '_L2TEST_card_friends', 'x', 'friends', false, false, 'medium', gen_random_uuid() FROM _fixture WHERE role_label = 'owner'
UNION ALL
SELECT id, id, id, 'test_course', '_L2TEST_card_private', 'x', 'private', false, false, 'medium', gen_random_uuid() FROM _fixture WHERE role_label = 'owner';

-- ============================================
-- ACTOR: OWNER — expect: sees all 3 tiers, both tables (via users_view_own_* policy)
-- ============================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'owner'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_public';
  INSERT INTO _r VALUES ('notes/owner/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_friends';
  INSERT INTO _r VALUES ('notes/owner/friends', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_private';
  INSERT INTO _r VALUES ('notes/owner/private', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_public';
  INSERT INTO _r VALUES ('flashcards/owner/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_friends';
  INSERT INTO _r VALUES ('flashcards/owner/friends', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_private';
  INSERT INTO _r VALUES ('flashcards/owner/private', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ============================================
-- ACTOR: ACCEPTED FRIEND — expect: public=1, friends=1 (the tier being newly enforced),
-- private=0
-- ============================================
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'friend'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_public';
  INSERT INTO _r VALUES ('notes/friend/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_friends';
  INSERT INTO _r VALUES ('notes/friend/friends', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_private';
  INSERT INTO _r VALUES ('notes/friend/private', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_public';
  INSERT INTO _r VALUES ('flashcards/friend/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_friends';
  INSERT INTO _r VALUES ('flashcards/friend/friends', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_private';
  INSERT INTO _r VALUES ('flashcards/friend/private', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ============================================
-- ACTOR: NON-FRIEND AUTHENTICATED STRANGER — CRITICAL: expect public=1, friends=0, private=0
-- ============================================
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM _fixture WHERE role_label = 'stranger'), 'role', 'authenticated')::text,
  true);

DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_public';
  INSERT INTO _r VALUES ('notes/stranger/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_friends';
  INSERT INTO _r VALUES ('notes/stranger/friends [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_private';
  INSERT INTO _r VALUES ('notes/stranger/private [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_public';
  INSERT INTO _r VALUES ('flashcards/stranger/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_friends';
  INSERT INTO _r VALUES ('flashcards/stranger/friends [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_private';
  INSERT INTO _r VALUES ('flashcards/stranger/private [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ============================================
-- ACTOR: ANON — locked decision (02/07/2026, confirmed against live 09): PRESERVE TO public,
-- so anon reads PUBLIC content directly (this was already the case pre-migration; the policies
-- target role `public`). CRITICAL: expect public=1, but friends=0 AND private=0 — anon must
-- NEVER see friends or private content. A non-zero friends/private here is a live exposure.
-- ============================================
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);

DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_public';
  INSERT INTO _r VALUES ('notes/anon/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_friends';
  INSERT INTO _r VALUES ('notes/anon/friends [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.notes WHERE title = '_L2TEST_note_private';
  INSERT INTO _r VALUES ('notes/anon/private [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_public';
  INSERT INTO _r VALUES ('flashcards/anon/public', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_friends';
  INSERT INTO _r VALUES ('flashcards/anon/friends [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
  SELECT count(*) INTO v_n FROM public.flashcards WHERE front_text = '_L2TEST_card_private';
  INSERT INTO _r VALUES ('flashcards/anon/private [CRITICAL]', '0', v_n::text, CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ============================================
-- Results
-- ============================================
RESET ROLE;
SELECT * FROM _r ORDER BY cell;

SELECT
  CASE WHEN count(*) FILTER (WHERE verdict = 'FAIL') = 0
    THEN 'PASS: all ' || count(*) || ' matrix cells passed'
    ELSE 'FAIL: ' || count(*) FILTER (WHERE verdict = 'FAIL') || ' of ' || count(*) || ' matrix cells failed — see rows above'
  END AS summary
FROM _r;

ROLLBACK;
