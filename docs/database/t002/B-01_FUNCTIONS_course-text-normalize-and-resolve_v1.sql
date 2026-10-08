-- Name: [FUNCTIONS] T-002 B-01 (v1) - pure course-text normalization (IMMUTABLE) and catalogue-reading canonical label resolver (STABLE)
--
-- Description: PERSISTENT DDL. Implements brief B v10 (0fe77dec72dc, Gate 1 given by the Founder on 04/10/2026) section 5.3a and plan v18 file B-01. Creates two functions and
-- changes nothing else (no table, no data, no trigger). Tier 1 file of the tiered workflow adopted on 08/10/2026: QA audits this exact file by hash (at most two rounds, blockers
-- only), the Founder authorizes the production run by hash. Run ONLY after that. The Supabase SQL Editor runs a selection in ONE transaction, so this file has no verification
-- and no ROLLBACK; verification is B-01_TEST, undo is B-01_ROLLBACK.
--
-- 1) public.normalize_course_text(p_text text) RETURNS text
--    Pure and IMMUTABLE (the only function allowed in an index expression or a generated column): collapses every run of whitespace to one space, trims, lower-cases.
--    NULL in, NULL out (STRICT). SECURITY INVOKER. Every built-in is schema-qualified (pg_catalog.), so the caller's search_path cannot change its behaviour. No table access.
--    Known limit, stated: lower() follows the database default collation; the platform database uses one fixed collation, which is what makes IMMUTABLE honest here.
--    Execute: owner and authenticated only. It runs inside generated columns and the disciplines index expression (brief B 4.1 and 6.4), which are evaluated as the writing role.
-- 2) public.resolve_canonical_course_label(p_label text) RETURNS text
--    STABLE (never IMMUTABLE: inserting a discipline changes its answer, so there is no function redefinition and no reindex when a discipline is added), SECURITY INVOKER,
--    pinned search_path = pg_catalog, public. Compares normalize_course_text of the input with that of: (a) every public.disciplines.name, active or not: returns the EXACT stored
--    name; else (b) the six non-platform catalogue labels of brief B 5.5 (CMA Foundation, CMA Intermediate, CMA Final, CS Foundation, CS Executive, CS Professional): returns the
--    exact catalogue text; else (c) the trimmed input unchanged (a genuine custom label). NULL in, NULL out. A blank input returns an empty string (callers validate).
--    Execute: owner only (it is called from SECURITY DEFINER functions and triggers that run as the owner).
--    OPEN for Gate 2 (a wording point, not a contract change): the six catalogue labels are written once, inside this function; B-06a must read them through this function or a
--    shared definition, never a second copy (plan 8; the B-06a catalog test).
--
-- Privilege hygiene: objects created by postgres are default-granted to anon, authenticated and service_role (T-001 FU4 evidence), so each function is REVOKEd from PUBLIC, anon,
-- authenticated and service_role first and then granted exactly as above.
-- Evidence relied on: D2 v3 run of 08/10/2026 (docs/discussions/evidence/T-002_D2-index_08-10-2026.md): PostgreSQL 17.6; disciplines has id uuid, name text NOT NULL, code text
-- NOT NULL, is_active, only its primary-key index; three rows CA Final, CA Foundation, CA Intermediate, no normalized-name collision (P5).

CREATE OR REPLACE FUNCTION public.normalize_course_text(p_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SECURITY INVOKER
AS $function$
  SELECT pg_catalog.lower(pg_catalog.btrim(pg_catalog.regexp_replace(p_text, '\s+', ' ', 'g')));
$function$;

CREATE OR REPLACE FUNCTION public.resolve_canonical_course_label(p_label text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_norm  text;
  v_match text;
BEGIN
  IF p_label IS NULL THEN
    RETURN NULL;
  END IF;

  v_norm := public.normalize_course_text(p_label);

  -- (a) a platform course: the exact stored name of the matching discipline, active or inactive (identity resolution uses every row)
  SELECT d.name
    INTO v_match
    FROM public.disciplines d
   WHERE public.normalize_course_text(d.name) = v_norm
   ORDER BY d.name
   LIMIT 1;
  IF v_match IS NOT NULL THEN
    RETURN v_match;
  END IF;

  -- (b) a catalogue label of brief B 5.5 (the six non-platform labels), in its exact catalogue text
  SELECT c.label
    INTO v_match
    FROM unnest(ARRAY['CMA Foundation', 'CMA Intermediate', 'CMA Final', 'CS Foundation', 'CS Executive', 'CS Professional']) AS c(label)
   WHERE public.normalize_course_text(c.label) = v_norm
   LIMIT 1;
  IF v_match IS NOT NULL THEN
    RETURN v_match;
  END IF;

  -- (c) a genuine custom label: the trimmed input, unchanged
  RETURN pg_catalog.btrim(p_label);
END;
$function$;

REVOKE ALL ON FUNCTION public.normalize_course_text(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.normalize_course_text(text) TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_canonical_course_label(text) FROM PUBLIC, anon, authenticated, service_role;
