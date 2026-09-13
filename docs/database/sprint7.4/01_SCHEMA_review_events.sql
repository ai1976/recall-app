-- Name: [SCHEMA] Sprint 7.4 — review_events (append-only per-review history)
--
-- Description:
--   Durable event log alongside `reviews` (which stays the current-state SRS
--   SSOT, unchanged shape/semantics). One row per grade, ever. No synthetic
--   backfill — history starts at deploy. Run this as its own Supabase SQL
--   Editor submission; let it COMMIT. Then run 02_FUNCTIONS in a separate
--   submission (apply_review needs this table to exist).
--
--   FK actions confirmed against the LIVE `reviews` table via Phase 0
--   introspection (00_DIAGNOSTIC, Q1) rather than assumed:
--     reviews_flashcard_id_fkey -> flashcards(id)  ON DELETE CASCADE
--     reviews_user_id_fkey      -> auth.users(id)  ON DELETE CASCADE  (NOT profiles!)
--   review_events matches both exactly — in particular user_id references
--   auth.users(id), not public.profiles(id), because that is what the table
--   it shadows actually does.
--
--   RLS: enabled, zero policies, zero grants. Every access goes through a
--   SECURITY DEFINER RPC (apply_review to write; analytics RPCs to read).

CREATE TABLE IF NOT EXISTS public.review_events (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  flashcard_id      uuid NOT NULL REFERENCES public.flashcards(id) ON DELETE CASCADE,
  reviewed_at       timestamptz NOT NULL DEFAULT now(),
  rating            text NOT NULL CHECK (rating IN ('hard','medium','easy')),
  is_correct        boolean,                 -- NULL = no deterministic verdict (self-grade only)
  question_type     text NOT NULL,           -- snapshot at review time
  topic_id          uuid,                    -- snapshot; NULL for custom_topic cards
  rung_before       smallint,                -- NULL = card was new (no prior ladder position)
  rung_after        smallint NOT NULL,
  status_after      text NOT NULL CHECK (status_after IN ('active','suspended','mastered')),
  interval_days     integer NOT NULL,
  next_review_date  date NOT NULL,
  source            text,                    -- NULL | 'review_session' | 'new_card' | 'exam_final_pass'
  study_session_id  uuid                     -- reserved; stays NULL — session logging rework is NOT this sprint
);

CREATE INDEX IF NOT EXISTS idx_review_events_user_time
  ON public.review_events (user_id, reviewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_review_events_card_time
  ON public.review_events (flashcard_id, reviewed_at DESC);

COMMENT ON TABLE public.review_events IS
  'Append-only per-review history. reviews stays the current-state SSOT — '
  'this table and reviews are written atomically in the same apply_review '
  'call and must never disagree. RevisOp-only: no assessment_id, no CA '
  'linkage, ever.';

ALTER TABLE public.review_events ENABLE ROW LEVEL SECURITY;
-- No client SELECT/INSERT/UPDATE/DELETE policy whatsoever — every access
-- is via a SECURITY DEFINER RPC (apply_review to write; new/extended
-- analytics RPCs to read).
REVOKE ALL ON public.review_events FROM PUBLIC, anon, authenticated;
