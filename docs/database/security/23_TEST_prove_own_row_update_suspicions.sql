-- ============================================================================
-- Name: [TEST] Prove or disprove the own-row UPDATE suspicions (friendships, reviews, notes, profile_courses)
-- Description: Everything runs inside BEGIN ... ROLLBACK - no data survives, so this is safe on production.
--   Each probe impersonates a REAL student (SET LOCAL ROLE authenticated + JWT sub) exactly as PostgREST
--   would, tries the write a malicious client could send, and records what actually happened:
--       'WRITE SUCCEEDED'  = the hole is real
--       'BLOCKED: <error>' = the write was refused (or 0 rows matched)
--   Column 'legit' marks probes that MUST succeed (baselines proving the harness works) - a baseline that
--   fails means the harness, not the policy, is the problem.
--   Side effects of triggers (counters, badges, notifications rows) are rolled back with everything else.
--   Run as its own script; the final SELECT is the result. Paste it back.
-- ============================================================================

BEGIN;
CREATE TEMP TABLE _r(seq int, check_name text, legit boolean, observed text, meaning text);

DO $$
DECLARE
  v_res   text[] := '{}';
  v_users uuid[];
  a uuid; b uuid; c uuid; d uuid; e uuid; x uuid;
  v_owner uuid; v_review_owner uuid;
  v_n int; v_err text;
  v_disc uuid;
BEGIN
  -- Six distinct students with no friendship rows among them (fixtures for the friendships probes).
  SELECT array_agg(id) INTO v_users FROM (
    SELECT p.id FROM public.profiles p
    WHERE p.role = 'student'
      AND NOT EXISTS (SELECT 1 FROM public.friendships f WHERE f.user_id = p.id OR f.friend_id = p.id)
    ORDER BY p.created_at DESC LIMIT 6) s;
  IF v_users IS NULL OR array_length(v_users, 1) < 6 THEN
    INSERT INTO _r VALUES (0, 'fixtures', false, 'need 6 students with no friendships', 'SKIP - relax the fixture filter');
    RETURN;
  END IF;
  a := v_users[1]; b := v_users[2]; c := v_users[3]; d := v_users[4]; e := v_users[5]; x := v_users[6];

  -- Pre-create a pending request X -> B as the server (for the recipient-accept baseline).
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (x, b, 'pending');

  -- ══ friendships ═══════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  -- F1 baseline: A legitimately sends a pending request to B.
  BEGIN
    INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, b, 'pending');
    v_res := v_res || 'F1 sender inserts a pending request (baseline)|true|WRITE SUCCEEDED|must succeed'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F1 sender inserts a pending request (baseline)|true|BLOCKED: ' || v_err || '|harness/policy problem');
  END;

  -- F2 THE SUSPICION: the SENDER flips their own outgoing request to accepted.
  BEGIN
    UPDATE public.friendships SET status = 'accepted' WHERE user_id = a AND friend_id = b;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('F2 SENDER self-accepts own outgoing request [CRITICAL]|false|' ||
      CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = forced friendship');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F2 SENDER self-accepts own outgoing request [CRITICAL]|false|BLOCKED: ' || v_err || '|');
  END;

  -- F3: direct INSERT of an already-accepted friendship (no request at all).
  BEGIN
    INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, c, 'accepted');
    v_res := v_res || 'F3 sender INSERTs a row already accepted [CRITICAL]|false|WRITE SUCCEEDED|forced friendship without a request'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F3 sender INSERTs a row already accepted [CRITICAL]|false|BLOCKED: ' || v_err || '|');
  END;

  -- F4: retarget an own row at a victim and accept it in the same statement.
  BEGIN
    INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, d, 'pending');
    UPDATE public.friendships SET friend_id = e, status = 'accepted' WHERE user_id = a AND friend_id = d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('F4 sender retargets friend_id and accepts [CRITICAL]|false|' ||
      CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = row hijack');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F4 sender retargets friend_id and accepts [CRITICAL]|false|BLOCKED: ' || v_err || '|');
  END;

  -- F5 baseline: the RECIPIENT (B) legitimately accepts the pending request X -> B.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  BEGIN
    UPDATE public.friendships SET status = 'accepted' WHERE user_id = x AND friend_id = b;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res := v_res || ('F5 RECIPIENT accepts a pending request (baseline)|true|' ||
      CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|must succeed');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('F5 RECIPIENT accepts a pending request (baseline)|true|BLOCKED: ' || v_err || '|harness/policy problem');
  END;

  -- ══ reviews ═══════════════════════════════════════════════════════════════
  RESET ROLE;
  SELECT r.user_id INTO v_review_owner FROM public.reviews r
  JOIN public.profiles p ON p.id = r.user_id WHERE p.role = 'student' LIMIT 1;
  IF v_review_owner IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_review_owner, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      -- No-op value change: proves WRITE capability without altering meaning.
      UPDATE public.reviews SET status = status
      WHERE id = (SELECT id FROM public.reviews WHERE user_id = v_review_owner LIMIT 1);
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('R1 student writes their own reviews row directly (bypassing apply_review)|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = SRS state/streak inputs are client-writable');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('R1 student writes their own reviews row directly (bypassing apply_review)|false|BLOCKED: ' || v_err || '|');
    END;
    RESET ROLE;
  END IF;

  -- ══ notes: owner-editable counter ═════════════════════════════════════════
  SELECT n.user_id INTO v_owner FROM public.notes n LIMIT 1;
  IF v_owner IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      UPDATE public.notes SET upvote_count = COALESCE(upvote_count, 0)
      WHERE id = (SELECT id FROM public.notes WHERE user_id = v_owner LIMIT 1);
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('N1 note owner writes the upvote_count column directly|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = counter is owner-writable (inflate own ranking)');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('N1 note owner writes the upvote_count column directly|false|BLOCKED: ' || v_err || '|(or column absent)');
    END;
    RESET ROLE;
  END IF;

  -- ══ profile_courses ═══════════════════════════════════════════════════════
  SELECT id INTO v_disc FROM public.disciplines LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.profile_courses (user_id, discipline_id) VALUES (a, v_disc);
    v_res := v_res || 'P1 STUDENT inserts a profile_courses row for themselves|false|WRITE SUCCEEDED|only matters if the DB or UI trusts it (see 22 block F)'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('P1 STUDENT inserts a profile_courses row for themselves|false|BLOCKED: ' || v_err || '|(error text may be a missing NOT NULL column, not a policy)');
  END;

  RESET ROLE;
  INSERT INTO _r
  SELECT ord, split_part(x_, '|', 1), split_part(x_, '|', 2)::boolean, split_part(x_, '|', 3), split_part(x_, '|', 4)
  FROM unnest(v_res) WITH ORDINALITY AS t(x_, ord);
END $$;

SELECT seq, check_name, legit AS must_succeed, observed, meaning FROM _r ORDER BY seq;
ROLLBACK;
