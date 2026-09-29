-- Name: [SCHEMA] DRAFT - revoke direct client writes on reviews   *** DO NOT DEPLOY YET ***
-- Status: DRAFT, CONDITIONS NOW MET (29/09/2026): 22 block E1 = all eight writers of `reviews`
--   (admin_delete_user_data, apply_review, reset_card, skip_card, skip_topic_cards, suspend_card,
--   suspend_topic_cards, unsuspend_card) are SECURITY DEFINER owned by postgres; 22 block E2 = both triggers on
--   reviews (fn_update_reviews_counter, fn_badge_check_reviews) are SECURITY DEFINER; 23 probe R1 = the direct
--   client write really succeeds; the two edge functions (cron-daily-study-summary, cron-review-reminders) only
--   read `reviews` (and run as service_role, which this REVOKE does not touch). Awaiting operator approval.
--   Original conditions, for the record: E1 all-definer, E2 caller-independent triggers, R1 confirmed.
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
