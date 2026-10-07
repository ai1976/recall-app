-- Name: [DIAGNOSTIC] T-001 brief C file C-03 pre-check 2 (v1) - which routines the row-level-security policies call, and whether those routines could write a due-input table
--
-- Description: READ-ONLY. Diagnostic 11 v4 (run W1, Gate 4 pending) listed 25 row-level-security policies on public tables whose USING or WITH CHECK expression calls
-- something other than a built-in, but it did not say WHICH routine each policy calls. QA Round 125 ruled that the C-03 manifest cannot classify the 102 clean
-- frontend routines as not-due-changing until those 25 preconditions are cleared by callee names and definitions (or an equivalent hand audit). This file returns,
-- for every such policy, the callee names it finds in the policy expression and, for each name, every routine it can resolve to (schema, name, language,
-- SECURITY DEFINER flag), plus for each resolved routine whose language is plpgsql or sql a list of the due-input tables for which its body has a write keyword
-- followed, in the same statement, by that table name (the same over-reporting "loose lead" used in diagnostic 11; an empty list means no lead, not proof).
-- The six due-input tables are reviews, my_cards_enrollment, friendships, flashcards, notes and profiles.
-- It returns names and flags only: NO policy text, NO function body or definition text, no table data and no identity.
-- How it moves the finish line (the standing rule for new diagnostics): QA ruled the 25 policy preconditions blocking for the classification of the 102 clean
-- routines. Without the callee names the C-03 manifest cannot be frozen and Gate 5 cannot be reached; with them each policy is cleared (or listed for a hand read)
-- in one round. It is the smallest read that answers the ruling.
-- Reading the result: a resolved public routine that is NOT in the W1 result (docs/discussions/evidence/T-001_C03-W1_07-10-2026.json) writes no due-input table
-- directly or transitively; a resolved routine in any other schema, or one in a language other than plpgsql or sql, cannot be analysed here and is listed for a
-- hand read; a callee token with an empty "resolved" list is a name the catalogue could not resolve and is also listed for a hand read.
-- Safety: one SELECT ... WITH, no DML, DDL, dynamic SQL, transaction control or application-function call. Only pg_policy, pg_class, pg_namespace, pg_proc,
-- pg_language, pg_get_expr, pg_get_functiondef (on routines of languages plpgsql and sql, read into an internal string for analysis only) and regular-expression
-- functions are used.
-- Blind spots, stated: the callee tokens are found lexically (a name followed by an opening parenthesis in the policy expression; operators and casts are not
-- calls); a name that matches routines in several schemas is reported for every match; the write-keyword check is lexical and over-reports; the transitive
-- callees of a non-public routine are not followed.
--
-- HOW TO RUN (one run): select the whole file (Ctrl+A in the file, Ctrl+C), paste it into the SQL Editor, click Run, copy the single result cell and paste it into a
-- Notepad file under the label W2; save it as docs/discussions/evidence/T-001_C03-W2-raw_<dd-mm-yyyy>.raw.txt (check that Notepad did not drop the .txt) and keep it
-- untouched. An error is evidence: save the error text under the label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN W2 =====
WITH pt AS (
  SELECT c.oid, c.relname::text AS relname
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
),
due(tbl) AS (
  VALUES ('reviews'), ('my_cards_enrollment'), ('friendships'), ('flashcards'), ('notes'), ('profiles')
),
pol AS (
  SELECT pc.relname, p.polname::text AS polname, p.polcmd::text AS cmd,
         lower(COALESCE(pg_get_expr(p.polqual, p.polrelid), '') || ' ' || COALESCE(pg_get_expr(p.polwithcheck, p.polrelid), '')) AS ex
  FROM pg_policy p JOIN pt pc ON pc.oid = p.polrelid
),
tk AS (
  SELECT DISTINCT p.relname, p.polname, p.cmd, regexp_replace(replace(m[1], '"', ''), '^public\.', '') AS nm
  FROM pol p, regexp_matches(p.ex, '([a-z0-9_."]+)\s*\(', 'g') m
),
sel AS (
  -- the same selection rule as the policy precondition of diagnostic 11 v4
  SELECT * FROM tk
  WHERE nm NOT IN ('auth.uid', 'auth.jwt', 'auth.role')
    AND (nm IN (SELECT x.proname::text
                FROM pg_proc x JOIN pg_namespace n ON n.oid = x.pronamespace
                WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast'))
         OR (nm ~ '^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$' AND split_part(nm, '.', 1) NOT IN ('pg_catalog', 'information_schema')))
),
cand AS (
  SELECT s.relname, s.polname, s.nm,
         x.oid AS poid, n.nspname::text AS sch, x.proname::text AS fn, l.lanname::text AS lang, x.prosecdef, x.prokind::text AS kind
  FROM sel s
  LEFT JOIN (pg_proc x
             JOIN pg_namespace n ON n.oid = x.pronamespace
             JOIN pg_language l ON l.oid = x.prolang)
    ON n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
   AND (s.nm = x.proname::text OR s.nm = n.nspname::text || '.' || x.proname::text)
),
lead AS (
  SELECT c.poid, d.tbl, k.op
  FROM (SELECT DISTINCT poid FROM cand WHERE poid IS NOT NULL AND lang IN ('plpgsql', 'sql') AND kind IN ('f', 'p')) c
  CROSS JOIN LATERAL (SELECT lower(pg_get_functiondef(c.poid)) AS body) b
  CROSS JOIN due d
  CROSS JOIN (VALUES ('insert'), ('update'), ('delete'), ('merge'), ('truncate')) k(op)
  WHERE b.body ~ ('(^|[^a-z0-9_])' || k.op || '[^a-z0-9_]([^;]*[^a-z0-9_])?' || d.tbl || '([^a-z0-9_]|$)')
)
SELECT jsonb_build_object(
  'run', 'W2',
  'policy_count_total', (SELECT count(*) FROM pol),
  'policy_callee_pairs', (SELECT count(*) FROM sel),
  'policies_with_callees', (SELECT count(*) FROM (SELECT DISTINCT relname, polname FROM sel) z),
  'policies', (SELECT COALESCE(jsonb_agg(po ORDER BY po->>'relation', po->>'policy'), '[]'::jsonb)
               FROM (SELECT jsonb_build_object(
                        'relation', s.relname, 'policy', s.polname, 'command', s.cmd,
                        'callees', (SELECT jsonb_agg(jsonb_build_object(
                                      'token', x.nm,
                                      'resolved', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                                     'schema', c.sch, 'name', c.fn, 'language', c.lang, 'security_definer', c.prosecdef,
                                                     'loose_due_write_leads', COALESCE((SELECT jsonb_agg(l.tbl || '.' || l.op ORDER BY l.tbl, l.op) FROM lead l WHERE l.poid = c.poid), '[]'::jsonb))
                                                   ORDER BY c.sch, c.fn), '[]'::jsonb)
                                                   FROM cand c
                                                   WHERE c.relname = s.relname AND c.polname = s.polname AND c.nm = x.nm AND c.poid IS NOT NULL))
                                    ORDER BY x.nm)
                                    FROM sel x WHERE x.relname = s.relname AND x.polname = s.polname)) AS po
                     FROM (SELECT DISTINCT relname, polname, cmd FROM sel) s) q)
) AS result;
