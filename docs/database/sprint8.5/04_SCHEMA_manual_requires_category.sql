-- [SCHEMA] Manual study sessions must carry a category, enforced in the DB
-- Description: Sprint 8.5 follow-up (quality-auditor finding, 16/09/2026).
-- The frontend requires a category before a manual session can be logged,
-- but study_sessions.category is nullable and its own CHECK only validates
-- the value when one is present — nothing in the database itself stops a
-- future write path (a bulk import, a different form, a regression) from
-- inserting source='manual', category=NULL and silently reintroducing the
-- exact gap this sprint exists to close. This constraint closes that gap at
-- the database layer, independent of the frontend.
--
-- NOT VALID means: not checked against rows that already exist (every
-- pre-8.5 manual row has category=NULL and must stay exactly as it is — no
-- backfill), but fully enforced on every INSERT and UPDATE from this point
-- forward. Confirmed via 03_DIAGNOSTIC that study_sessions has no UPDATE
-- path at all (no RLS UPDATE policy, no function mutates it, no trigger is
-- attached to it) — rows are write-once, so "future INSERT" is the only
-- case this constraint will ever actually gate in practice.
--
-- Deliberately a second, separate CHECK rather than folding into the
-- existing category-value CHECK from 01_SCHEMA — that one governs "if a
-- category is given, it must be a real one" and applies to every row
-- regardless of source; this one governs "if source is manual, a category
-- is mandatory" and leaves source='study_mode' rows (which have no category
-- concept) untouched.
-- Run 03_DIAGNOSTIC_confirm_study_sessions_immutable.sql first.

ALTER TABLE study_sessions
  ADD CONSTRAINT study_sessions_manual_requires_category
  CHECK (source <> 'manual' OR category IS NOT NULL) NOT VALID;
