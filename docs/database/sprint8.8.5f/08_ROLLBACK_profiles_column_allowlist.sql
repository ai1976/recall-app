-- [SCHEMA] ROLLBACK for 06 (Sprint 8.8.5f step 3): restore the table-wide default grants on profiles that existed on 01/10/2026
-- (read by 00 blocks B and C: anon and authenticated both held SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER).
-- Use only if the app breaks after step 3 and a quick fix is not possible. This re-opens email to every signed-in user.
GRANT ALL ON TABLE public.profiles TO anon, authenticated;
