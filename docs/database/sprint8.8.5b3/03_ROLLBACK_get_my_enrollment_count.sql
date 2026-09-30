-- [FUNCTIONS] ROLLBACK for 01: remove get_my_enrollment_count
-- Description: Only run if the new-student dashboard check is reverted. Nothing else depends on this function.
DROP FUNCTION IF EXISTS public.get_my_enrollment_count(uuid);
