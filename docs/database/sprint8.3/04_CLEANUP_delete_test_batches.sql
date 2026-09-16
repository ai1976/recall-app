-- ============================================================================
-- Name: [CLEANUP] Delete the 2 disposable test batch groups from Sprint 8.3
-- Description: Sprint 8.3's screenshot capture created 2 throwaway batch
--   groups ("TEST — Demo Batch (Screenshot Sandbox, delete after)" and
--   "TEST 2 — Demo Batch (Screenshot Sandbox, delete after)") plus one dummy
--   membership row each (a test student account, "TestOutlook", and the
--   operator's own super_admin account on the first one). Per the Quality
--   Auditor's sprint-close disposition (16/09/2026), these must be cleaned
--   up before the sprint is considered operationally closed. These are
--   named "delete after" by design — a real DELETE, not an archive, since
--   there is no report/history worth preserving for sandbox data.
-- Run in: Supabase Dashboard -> SQL Editor -> New Query. Run the preview
--   SELECT first and confirm it shows only the 2 named sandbox batches
--   before running the DELETE statements below it.
-- ============================================================================

-- STEP 1 — Preview: confirm this matches ONLY the 2 disposable sandboxes,
-- nothing else, before deleting anything.
SELECT id, name, is_batch_group, group_type, created_at
FROM study_groups
WHERE name LIKE '%Screenshot Sandbox%';

-- STEP 2 — Preview the membership rows that will be deleted alongside them.
SELECT sgm.id, sg.name AS group_name, p.email, sgm.status
FROM study_group_members sgm
JOIN study_groups sg ON sg.id = sgm.group_id
JOIN profiles p ON p.id = sgm.user_id
WHERE sg.name LIKE '%Screenshot Sandbox%';

-- ============================================================================
-- STEP 3 — Only run below after confirming STEP 1/2 show exactly the 2
-- sandbox batches and nothing else.
-- ============================================================================

-- Delete membership rows first (defensive — do not assume ON DELETE CASCADE
-- is defined on study_group_members.group_id without having confirmed it).
DELETE FROM study_group_members
WHERE group_id IN (
  SELECT id FROM study_groups WHERE name LIKE '%Screenshot Sandbox%'
);

-- Delete the batch group rows themselves.
DELETE FROM study_groups
WHERE name LIKE '%Screenshot Sandbox%';

-- STEP 4 — Verify: both queries below should return 0 rows.
SELECT count(*) AS remaining_sandbox_groups
FROM study_groups
WHERE name LIKE '%Screenshot Sandbox%';

SELECT count(*) AS remaining_sandbox_memberships
FROM study_group_members sgm
JOIN study_groups sg ON sg.id = sgm.group_id
WHERE sg.name LIKE '%Screenshot Sandbox%';
