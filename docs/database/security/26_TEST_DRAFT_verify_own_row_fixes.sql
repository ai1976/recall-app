-- Name: [TEST] DRAFT - verify the friendships guard (24) and the reviews privilege revoke (25)
-- Status: DRAFT - run only AFTER 24 (and 25 if approved) are deployed. Rollback-only (BEGIN...ROLLBACK).
-- Description: Impersonates real students (SET LOCAL ROLE authenticated + JWT sub). Expected verdicts are
--   listed per check. It proves both halves: the attacks are BLOCKED, and every real workflow still works:
--     - sender sends a request (INSERT, and UPSERT re-send after a rejection)
--     - recipient accepts / rejects
--     - either party deletes (unfriend / decline-by-delete)
--     - SECURITY DEFINER RPCs (suspend_card / unsuspend_card) still write `reviews` after the revoke
--   Results are collected in a variable and inserted after RESET ROLE (temp table not visible while switched).

BEGIN;
CREATE TEMP TABLE _r(seq int, check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_res text[] := '{}';
  v_users uuid[]; a uuid; b uuid; c uuid; d uuid; e uuid; x uuid; y uuid;
  v_n int; v_err text; v_card uuid; v_rev_user uuid;
BEGIN
  SELECT array_agg(id) INTO v_users FROM (
    SELECT p.id FROM public.profiles p
    WHERE p.role = 'student'
      AND NOT EXISTS (SELECT 1 FROM public.friendships f WHERE f.user_id = p.id OR f.friend_id = p.id)
    ORDER BY p.created_at DESC LIMIT 7) s;
  IF v_users IS NULL OR array_length(v_users, 1) < 7 THEN
    INSERT INTO _r VALUES (0, 'fixtures', '7 students without friendships', 'missing', 'SKIP');
    RETURN;
  END IF;
  a := v_users[1]; b := v_users[2]; c := v_users[3]; d := v_users[4]; e := v_users[5]; x := v_users[6]; y := v_users[7];

  -- Server-side fixtures: pending X -> B (recipient-accept), and a REJECTED Y -> A row (sender re-send).
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (x, b, 'pending');
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, y, 'rejected');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  -- ── attacks: all must be BLOCKED ─────────────────────────────────────────
  BEGIN INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, b, 'pending');
    v_res := v_res || 'F1 sender sends pending request|allowed|allowed|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F1 sender sends pending request|allowed|' || left(v_err, 40) || '|FAIL'); END;

  BEGIN UPDATE public.friendships SET status = 'accepted' WHERE user_id = a AND friend_id = b;
    v_res := v_res || 'F2 sender self-accepts [CRITICAL]|blocked|WRITE SUCCEEDED|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F2 sender self-accepts [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  BEGIN INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, c, 'accepted');
    v_res := v_res || 'F3 sender inserts already-accepted row [CRITICAL]|blocked|WRITE SUCCEEDED|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F3 sender inserts already-accepted row [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  BEGIN INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, d, 'pending');
        UPDATE public.friendships SET friend_id = e, status = 'accepted' WHERE user_id = a AND friend_id = d;
    v_res := v_res || 'F4 sender retargets row and accepts [CRITICAL]|blocked|WRITE SUCCEEDED|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F4 sender retargets row and accepts [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  BEGIN INSERT INTO public.friendships (user_id, friend_id, status) VALUES (b, e, 'pending');  -- forging someone else as sender
    v_res := v_res || 'F5 caller sends a request AS another user [CRITICAL]|blocked|WRITE SUCCEEDED|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F5 caller sends a request AS another user [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' OR v_err ILIKE '%row-level security%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

  -- ── real workflows: all must still work ──────────────────────────────────
  -- F6 sender re-sends via the app's UPSERT after the recipient had rejected (a -> y is 'rejected').
  BEGIN
    INSERT INTO public.friendships (user_id, friend_id, status, updated_at) VALUES (a, y, 'pending', now())
    ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'pending', updated_at = EXCLUDED.updated_at;
    v_res := v_res || 'F6 sender re-sends after rejection (app UPSERT)|allowed|allowed|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F6 sender re-sends after rejection (app UPSERT)|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err); END;

  -- F7 recipient B accepts X -> B (baseline for both accept UIs).
  PERFORM set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  BEGIN UPDATE public.friendships SET status = 'accepted', updated_at = now() WHERE user_id = x AND friend_id = b;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('F7 recipient accepts pending request|allowed|' || v_n || ' row|' ||
             CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F7 recipient accepts pending request|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err); END;

  -- F8 recipient B rejects A -> B (the pending row created in F1), NotificationCenter style.
  BEGIN UPDATE public.friendships SET status = 'rejected', updated_at = now() WHERE user_id = a AND friend_id = b;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('F8 recipient rejects pending request|allowed|' || v_n || ' row|' ||
             CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F8 recipient rejects pending request|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err); END;

  -- F9 recipient deletes a request (FriendRequests reject-by-delete / unfriend).
  BEGIN DELETE FROM public.friendships WHERE user_id = x AND friend_id = b;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('F9 party deletes a friendship row|allowed|' || v_n || ' row|' ||
             CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F9 party deletes a friendship row|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err); END;

  -- ── reviews (only meaningful once 25 is deployed) ────────────────────────
  RESET ROLE;
  SELECT r.user_id, r.flashcard_id INTO v_rev_user, v_card
  FROM public.reviews r JOIN public.profiles p ON p.id = r.user_id
  WHERE p.role = 'student' AND r.status = 'active' LIMIT 1;
  IF v_rev_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_rev_user, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';

    BEGIN UPDATE public.reviews SET status = status WHERE user_id = v_rev_user AND flashcard_id = v_card;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('R1 direct client write to reviews [needs 25]|blocked|' ||
               CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE '0 rows' END || '|' ||
               CASE WHEN v_n > 0 THEN 'FAIL (expected only if 25 not deployed)' ELSE 'PASS' END);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('R1 direct client write to reviews [needs 25]|blocked|' || left(v_err, 40) || '|' ||
               CASE WHEN v_err ILIKE '%permission denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END); END;

    -- R2 the real path still works: SECURITY DEFINER suspend / unsuspend write reviews.
    BEGIN
      PERFORM public.suspend_card(v_rev_user, v_card);
      PERFORM public.unsuspend_card(v_rev_user, v_card);
      v_res := v_res || 'R2 suspend_card + unsuspend_card (definer RPCs) still write reviews|allowed|allowed|PASS'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('R2 suspend_card + unsuspend_card (definer RPCs) still write reviews|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err); END;
    RESET ROLE;
  END IF;

  INSERT INTO _r
  SELECT ord, split_part(x_, '|', 1), split_part(x_, '|', 2), split_part(x_, '|', 3), split_part(x_, '|', 4)
  FROM unnest(v_res) WITH ORDINALITY AS t(x_, ord);
END $$;

SELECT * FROM _r ORDER BY seq;
ROLLBACK;
