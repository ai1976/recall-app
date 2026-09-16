-- [SCHEMA] Add exam date tracking to profiles
-- Description: Sprint 8.4 (Exam Date Field). Adds exam_date (exact date, once
-- known), exam_month (1st-of-month placeholder used only before an exact date
-- is announced), and has_dismissed_exam_prompt (one-time dismissal of the
-- post-first-login exam-date popup, same pattern as has_dismissed_goal_prompt)
-- to `profiles`. No default on the two date columns, no backfill — every
-- pre-existing student sees the CTA/popup exactly like a new student who
-- skipped it, per D-15 (never guess what should be an explicit action).
-- Run 00_DIAGNOSTIC_confirm_no_exam_date_columns.sql first.

ALTER TABLE profiles
  ADD COLUMN exam_date date,
  ADD COLUMN exam_month date CHECK (exam_month IS NULL OR EXTRACT(DAY FROM exam_month) = 1),
  ADD COLUMN has_dismissed_exam_prompt boolean NOT NULL DEFAULT false;
