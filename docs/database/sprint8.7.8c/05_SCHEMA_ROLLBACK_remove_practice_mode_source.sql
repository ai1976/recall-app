-- Name: [ROLLBACK] Remove 'practice_mode' from study_sessions_source_check
-- Description: Reverts 04_SCHEMA_add_practice_mode_source.sql. Only safe to run if no
-- study_sessions row with source='practice_mode' exists yet — otherwise those rows will violate
-- the narrowed constraint and the ALTER will fail (which is the correct, safe failure mode; do not
-- delete practice_mode rows just to force this through without checking with Anand first).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.study_sessions WHERE source = 'practice_mode') THEN
    RAISE EXCEPTION 'Refusing rollback: practice_mode rows exist in study_sessions — resolve with Anand first';
  END IF;
END $$;

ALTER TABLE public.study_sessions DROP CONSTRAINT study_sessions_source_check;

ALTER TABLE public.study_sessions ADD CONSTRAINT study_sessions_source_check
  CHECK (source = ANY (ARRAY['manual'::text, 'study_mode'::text]));
