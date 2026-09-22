-- Name: [SCHEMA] My Cards enrollment + Practice attempts — foundation tables (Sprint 8.7.8b)
--
-- Description: Two new tables for the My Cards Enrollment epic (8.7.8a diagnostic is the design of
-- record — docs/active/design-review/my-cards-enrollment-proposal.md).
--
--   my_cards_enrollment — durable "this external card belongs to this student's My Cards" marker.
--     Independent of reviews.status (§8 of the proposal): a membership row survives Pause/Resume,
--     and Remove soft-deletes (status='removed') rather than hard-deleting, because the Pause-vs-
--     Remove distinction on a suspended `reviews` row is resolved ENTIRELY by this table's own
--     status column (proposal §8) — no new value is added to reviews.status for this.
--
--   practice_attempts — append-only log of Practice/Explore interactions. Zero SRS side effect by
--     design: no FK/trigger touches reviews, review_events, badges, streaks, or user_stats.
--
-- Security posture, both tables: RLS enabled, ZERO client-facing policies, ZERO direct grants to
-- PUBLIC/anon/authenticated — reproduces review_events' own precedent exactly (docs/active/
-- blueprint.md §2.4A). No client may query either table directly; all access is through the four
-- SECURITY DEFINER RPCs in 02_FUNCTIONS_my_cards_rpcs.sql.
--
-- FK convention: user_id -> auth.users(id) ON DELETE CASCADE, matching reviews.user_id and
-- review_events.user_id (both confirmed live FK to auth.users, NOT profiles.id — DATABASE_SCHEMA.md
-- §2.4A). flashcard_id -> flashcards(id) ON DELETE CASCADE, matching every other per-user,
-- per-card table in this schema (reviews.flashcard_id, review_events.flashcard_id).
--
-- PK convention: my_cards_enrollment.id is uuid (matches reviews' own membership/state-table
-- convention — this is a durable fact per (user, card), not a pure append-only log).
-- practice_attempts.id is bigint GENERATED ALWAYS AS IDENTITY, matching review_events.id — the
-- established convention for this schema's append-only event/log tables (confirmed live,
-- DATABASE_SCHEMA.md §2.4A line 450).

CREATE TABLE public.my_cards_enrollment (
  id           uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  flashcard_id uuid NOT NULL REFERENCES public.flashcards(id) ON DELETE CASCADE,
  added_at     timestamptz NOT NULL DEFAULT now(),
  status       text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'removed')),
  UNIQUE (user_id, flashcard_id)
);

CREATE INDEX idx_my_cards_enrollment_user_active
  ON public.my_cards_enrollment (user_id)
  WHERE status = 'active';

ALTER TABLE public.my_cards_enrollment ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.my_cards_enrollment FROM PUBLIC, anon, authenticated;

CREATE TABLE public.practice_attempts (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  flashcard_id uuid NOT NULL REFERENCES public.flashcards(id) ON DELETE CASCADE,
  attempted_at timestamptz NOT NULL DEFAULT now(),
  is_correct   boolean
);

CREATE INDEX idx_practice_attempts_user_attempted
  ON public.practice_attempts (user_id, attempted_at DESC);

ALTER TABLE public.practice_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.practice_attempts FROM PUBLIC, anon, authenticated;

-- No triggers on either table. In particular, practice_attempts must never gain a trigger that
-- writes to reviews / review_events / badge tables / streak tables / user_stats — this is the
-- guardrail the sprint prompt calls out explicitly; do not add one later without re-reading it.
