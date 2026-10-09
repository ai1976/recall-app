-- Name: [DIAGNOSTIC] T-002 D6 (v2; v1 failed with 2201B because PostgreSQL limits a regex repetition count to 255, nothing was returned) - every database routine that inserts or updates flashcards or notes: the exact statements, to map each to a B-05 transition row
--
-- Description: READ-ONLY (Tier 0). Answers the one blocking finding of QA Round 81 on B-05 v1 ("close the exact live-writer inventory"). B-05's trigger fires on every
-- INSERT and on every UPDATE of flashcards and notes, so the question is which DATABASE-SIDE routines (functions, procedures, trigger functions) write those two
-- tables and what they put in subject_id, discipline_id and target_course. D3 (08/10/2026) listed leads by name and flag only; this file returns, for each live
-- routine whose body contains an INSERT INTO / UPDATE / MERGE INTO of flashcards or notes, the identity (schema, name, argument types, language, security mode,
-- owner), md5 of the stored body (and of the body with carriage returns removed, the value comparable with a repository file), and each matching statement
-- text (whitespace collapsed, up to the first semicolon, shown at most 1,500 characters; the three flags are computed on the uncut text; raw_length is the uncut length), with three flags saying whether that text names
-- subject_id, discipline_id or target_course. A second list names routines that mention flashcards or notes together with EXECUTE, COPY or MERGE words but
-- have no direct statement match (dynamic-SQL leads, identities only). Extension-owned routines are excluded and counted.
-- Blind spots, stated: this is a text scan of stored routine bodies, not a call graph; a statement of more than 1,500 characters after the table name is cut
-- (the flags are computed on the uncut text); a routine written with a SQL-standard body (BEGIN ATOMIC) has no stored text and is
-- counted in sql_standard_body_routines (D3 P2 already read such routines through facts, and none names these tables); dynamic SQL that builds a table name
-- from a variable is not seen; application code and cron jobs are covered by D4/D5 and D3 P4, not here.
-- Safety: ONE SELECT / WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
--
-- HOW TO RUN (one run): select the whole text from the first WITH to the closing semicolon, click Run, copy the single result cell, paste it unchanged into
-- a Notepad file and save it as docs/discussions/evidence/T-002_D6-raw_<dd-mm-yyyy>.raw.txt. A paste can be truncated: if the cell is cut, stop and report.
-- An error is evidence: save the error text, do not edit and re-run. Check in the output: "tool_version":"D6-v2" and a numeric "routines_scanned".

WITH r AS (
  SELECT p.oid, n.nspname AS schema_name, p.proname AS name, l.lanname AS language, p.prosecdef AS security_definer,
         pg_get_userbyid(p.proowner) AS owner, pg_get_function_identity_arguments(p.oid) AS args, p.prosrc,
         EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e') AS in_extension
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p')
),
own AS (SELECT * FROM r WHERE NOT in_extension),
direct AS (
  SELECT o.*, (SELECT jsonb_agg(jsonb_build_object(
                'statement', s.stmt,
                'raw_length', s.raw_len,
                'names_subject_id', s.full_stmt ~* '\msubject_id\M',
                'names_discipline_id', s.full_stmt ~* '\mdiscipline_id\M',
                'names_target_course', s.full_stmt ~* '\mtarget_course\M') ORDER BY s.ord)
              FROM (SELECT m.ord, length(m.g[1]) AS raw_len, regexp_replace(m.g[1], '\s+', ' ', 'g') AS full_stmt, left(regexp_replace(m.g[1], '\s+', ' ', 'g'), 1500) AS stmt
                    FROM regexp_matches(o.prosrc,
                      '(\m(?:insert\s+into|update|merge\s+into)\s+(?:only\s+)?(?:"?public"?\.)?"?(?:flashcards|notes)"?\M[^;]*)', 'gi')
                         WITH ORDINALITY AS m(g, ord)) s) AS statements
  FROM own o
  WHERE o.prosrc ~* '\m(?:insert\s+into|update|merge\s+into)\s+(?:only\s+)?(?:"?public"?\.)?"?(?:flashcards|notes)"?\M'
),
loose AS (
  SELECT o.schema_name, o.name, o.args, o.language
  FROM own o
  WHERE o.prosrc ~* '\m(flashcards|notes)\M' AND o.prosrc ~* '\m(execute|copy|merge)\M'
    AND NOT EXISTS (SELECT 1 FROM direct d WHERE d.oid = o.oid)
)
SELECT jsonb_build_object(
  'run', 'D6',
  'tool_version', 'D6-v2',
  'server_version', current_setting('server_version'),
  'routines_scanned', (SELECT count(*) FROM own),
  'extension_routines_excluded', (SELECT count(*) FROM r WHERE in_extension),
  'sql_standard_body_routines', (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                 WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND p.prokind IN ('f', 'p') AND p.prosqlbody IS NOT NULL),
  'routines_with_direct_statement', (SELECT count(*) FROM direct),
  'writers', COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'schema', d.schema_name, 'name', d.name, 'args', d.args, 'language', d.language, 'security_definer', d.security_definer, 'owner', d.owner,
      'src_md5', md5(d.prosrc), 'src_md5_no_cr', md5(replace(d.prosrc, chr(13), '')), 'statements', d.statements)
      ORDER BY d.schema_name, d.name, d.args) FROM direct d), '[]'::jsonb),
  'dynamic_or_bulk_leads_without_direct_statement', COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'schema', l.schema_name, 'name', l.name, 'args', l.args, 'language', l.language) ORDER BY l.schema_name, l.name, l.args) FROM loose l), '[]'::jsonb)
) AS result;
