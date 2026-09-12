-- [SCHEMA] Add has_dismissed_goal_prompt to profiles
-- Description: Backs the Sprint 7.3-B "no goal set" dismissible line on the
-- student dashboard — once a student taps "Not now", this flag persists so
-- the line never reappears. Same self-service pattern as has_seen_onboarding
-- (direct client update from Dashboard.jsx, gated by existing profiles RLS:
-- users update their own row only). Run once during migration.
--
-- URGENT: the frontend already selects this column (Dashboard.jsx's profile
-- fetch) as of Sprint 7.3, so until this runs, that select 400s and the
-- dashboard silently loses name/course/goal personalization for every
-- student. Run this first.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS has_dismissed_goal_prompt boolean NOT NULL DEFAULT false;
