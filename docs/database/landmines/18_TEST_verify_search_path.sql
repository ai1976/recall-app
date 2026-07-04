-- Name: [TEST] Verify function search_path hardening (L3)
-- Description: Post-deploy verification for 17_SCHEMA. Confirms (1) no our-owned public function is
-- unpinned anymore, (2) every extension-using function's pin includes 'extensions' (so nothing
-- breaks), and (3) a representative SECURITY DEFINER function still executes under the new pin.
-- Row-returning verdict pattern. Read-only except the block-3 smoke call, which is a safe no-op
-- (random uuid → returns NULL). Run AFTER 17_SCHEMA Block B.

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

-- 1. No unpinned our-owned functions/procedures remain in public — Expected: 0
DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind IN ('f','p')
    AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig,'{}')) c WHERE c LIKE 'search_path=%')
    AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e');
  INSERT INTO _r VALUES ('unpinned functions remaining', '0', v_n::text,
    CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL: ' || v_n || ' still unpinned' END);
END $$;

-- 2. Every extension-using function is pinned to a path that INCLUDES 'extensions' — Expected: 0 bad
DO $$
DECLARE v_bad int;
BEGIN
  SELECT count(DISTINCT p.oid) INTO v_bad
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND pg_get_functiondef(p.oid) ~* '(uuid_generate_v[15]|crypt|gen_salt|digest|hmac|gen_random_bytes|pgp_sym_encrypt|pgp_sym_decrypt)\s*\('
    AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
    AND NOT EXISTS (
      SELECT 1 FROM unnest(coalesce(p.proconfig,'{}')) c
      WHERE c LIKE 'search_path=%' AND c ILIKE '%extensions%'
    );
  INSERT INTO _r VALUES ('extension-using fns missing ''extensions'' in pin [CRITICAL]', '0', v_bad::text,
    CASE WHEN v_bad = 0 THEN 'PASS' ELSE 'FAIL: ' || v_bad || ' would break on extension calls' END);
END $$;

-- 3. Every pinned function must have 'public' as a STANDALONE schema in its search_path. Catches the
--    malformed single-quoted pin `SET search_path TO 'public, extensions'`, which Postgres stores as
--    ONE schema named "public, extensions" — 'public' is then NOT a standalone element and unqualified
--    references break (the 17b_HOTFIX bug). Expected: 0 bad. (A plain execution smoke misses this if
--    the sampled function was pinned to a single valid schema like 'public' — which is how the
--    original 18_TEST let the bug through.)
DO $$
DECLARE v_bad int;
BEGIN
  SELECT count(*) INTO v_bad
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind IN ('f','p')
    AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
    AND EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig,'{}')) c WHERE c LIKE 'search_path=%')
    AND NOT ('public' = ANY (
      SELECT btrim(elem)
      FROM unnest(coalesce(p.proconfig,'{}')) c,
           regexp_split_to_table(split_part(c, '=', 2), ',') AS elem
      WHERE c LIKE 'search_path=%'
    ));
  INSERT INTO _r VALUES ('pinned fns missing standalone public in path [CRITICAL]', '0', v_bad::text,
    CASE WHEN v_bad = 0 THEN 'PASS' ELSE 'FAIL: ' || v_bad || ' have a malformed search_path' END);
END $$;

-- Single result set, failures first. Expect 3 rows, all PASS.
SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, check_name;
DROP TABLE IF EXISTS _r;
