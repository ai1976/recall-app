-- ============================================================
-- Name: [DIAGNOSTIC] Verify CA disciplines exist and are active
-- Description: Run this BEFORE the backfill (02) to confirm that
--   CA Foundation, CA Intermediate, and CA Final all exist in the
--   disciplines table with is_active = TRUE. A missing or inactive
--   discipline will cause the backfill JOIN to silently skip that user.
--
-- Run order: 03 of 04 (run BEFORE 02, AFTER 01)
-- ============================================================

-- Step 1: Check the three core CA disciplines
SELECT
  id,
  name,
  code,
  is_active,
  order_num
FROM disciplines
WHERE name IN ('CA Foundation', 'CA Intermediate', 'CA Final')
ORDER BY order_num;

-- Expected: 3 rows, all with is_active = true
-- If any row is missing, insert it (adjust order_num as needed):
--   INSERT INTO disciplines (name, code, is_active, order_num)
--   VALUES ('CA Foundation', 'CAFND', true, 1);

-- If any row shows is_active = false, activate it:
--   UPDATE disciplines
--   SET is_active = TRUE
--   WHERE name IN ('CA Foundation', 'CA Intermediate', 'CA Final');

-- Step 2: Show ALL active disciplines (to plan future multi-course additions)
SELECT id, name, code, is_active, order_num
FROM disciplines
WHERE is_active = TRUE
ORDER BY order_num, name;
