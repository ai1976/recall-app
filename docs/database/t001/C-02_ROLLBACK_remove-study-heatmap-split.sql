-- Name: [FUNCTIONS] T-001 C-02 ROLLBACK (v1) - remove the new study-heatmap function
--
-- Description: PERSISTENT DDL (undo of C-02_FUNCTIONS_study-heatmap-split.sql). Run only after the Founder has authorized it (Gate 2 for this exact
-- hash, as for every SQL file). C-02 added one function and changed nothing else (the live get_study_heatmap was never altered), so the undo is a
-- DROP. Run it only when no deployed frontend calls get_study_heatmap_split (the frontend that uses it is brief C file C-03; roll that back first).
-- After use, run RUN P1 of diagnostic 10 again: get_study_heatmap_split must be absent and the definition_md5 and execute_roles of get_study_heatmap
-- must equal the values saved before C-02 (it was never touched).
-- The Supabase SQL Editor runs one selection in ONE transaction; this file has no verification and no ROLLBACK.

DROP FUNCTION IF EXISTS public.get_study_heatmap_split(uuid, integer);
