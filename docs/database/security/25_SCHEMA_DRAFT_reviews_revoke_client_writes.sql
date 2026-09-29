-- Name: [SCHEMA] DRAFT - revoke direct client writes on reviews   *** DO NOT DEPLOY YET ***
-- Status: DRAFT and CONDITIONAL. Deploy only if 22 block E1 shows every writer of `reviews` is a SECURITY
--   DEFINER function (so revoking client privileges cannot break it), 22 block E2 shows the triggers on
--   reviews do not depend on the caller's own privileges, AND 23 probe R1 shows the write really succeeds.
--   The client code search (src/) found NO direct write to reviews - every `.from('reviews')` is a SELECT -
--   all writes go through RPCs (apply_review, skip_card, suspend_card, unsuspend_card, reset_card, ...).
-- Description: `reviews` is the single source of truth for SRS progress, streak inputs and badge counters,
--   yet the own-row UPDATE policy (no WITH CHECK) plus table-level grants let a signed-in client write its
--   own rows directly, bypassing apply_review's enrollment / suspended guards (D-32) and any future
--   server-side rule. Unlike `profiles`, this table has NO legitimate client writer, so revoking write
--   privileges is safe and not brittle (nothing to re-grant column by column). SELECT is untouched, so
--   every progress/heatmap/My Study read keeps working. SECURITY DEFINER RPCs run as their owner and keep
--   writing normally.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.reviews FROM authenticated, anon;
