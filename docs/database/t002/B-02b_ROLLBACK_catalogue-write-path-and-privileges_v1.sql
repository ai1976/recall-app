-- Name: [SCHEMA] T-002 B-02b ROLLBACK (v1) - restore the catalogue-table privileges and remove the three admin policies
--
-- Description: PERSISTENT DDL, the undo of B-02b_SCHEMA_catalogue-write-path-and-privileges_v1.sql. Before B-02b (D2 v3 P4, 08/10/2026) anon and authenticated each held ALL eight table
-- privileges (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN) on disciplines, subjects and topics, so the rollback grants them back, and removes the three
-- policies B-02b added (admin_insert_subjects, admin_update_subjects, admin_insert_topics). The policies that existed before (disciplines: read, admin_insert_disciplines; subjects
-- and topics: read) are untouched. Run it BEFORE B-02a_ROLLBACK and B-01_ROLLBACK. Exact undo order for the whole stream: B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01.
-- Note: restoring ALL privileges re-opens client TRUNCATE; the B-02a TRUNCATE guard (if B-02a is still in place) still refuses it.

DROP POLICY IF EXISTS admin_insert_topics ON public.topics;
DROP POLICY IF EXISTS admin_update_subjects ON public.subjects;
DROP POLICY IF EXISTS admin_insert_subjects ON public.subjects;

GRANT ALL ON TABLE public.disciplines, public.subjects, public.topics TO anon;
GRANT ALL ON TABLE public.disciplines, public.subjects, public.topics TO authenticated;
