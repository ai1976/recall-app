-- [SCHEMA] ROLLBACK for 07: restore the previous (broad) table privileges on study_sessions
-- Description: Puts back exactly what the 01 diagnostic found on 30/09/2026. Only run if 07 breaks something
--   unexpected; the broad grants are not needed by the app.

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.study_sessions TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.study_sessions TO authenticated;
