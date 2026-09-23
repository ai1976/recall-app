-- Name: [TEST] Mastered-card Pause exclusion — disposable fixture (Sprint 8.7.8d live verification)
--
-- Description: This account's only real mastered card is a pre-D-27 orphaned reviews row
-- (professor-authored, never enrolled) that correctly does not appear in My Cards at all — so
-- there is no live mastered card currently sitting in My Cards to click through. This temporarily
-- flips the "Section 80C" card (Income Tax > Deductions from Gross Total Income, external,
-- currently status='active', added via Practice in the prior verification pass) to status='mastered'
-- so the My Cards page's Mastered-badge / no-Pause / no-Resume / Remove-still-available behavior can
-- be clicked through live. Run block 1, verify in the browser, then run block 2 to revert.
--
-- Safe: touches exactly one reviews row for one known test student
-- (email ai@moreclassescommerce.com's TestOutlook-style test account), identified by
-- flashcard front_text match, not a broad predicate.

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- BLOCK 1 — apply the fixture (run this first, then reload /dashboard/my-cards in the browser)
-- ─────────────────────────────────────────────────────────────────────────────────────────────
UPDATE public.reviews r
SET status = 'mastered'
FROM public.flashcards f
WHERE r.flashcard_id = f.id
  AND f.front_text = 'What is the maximum deduction under Section 80C?'
  AND r.status = 'active'
RETURNING r.user_id, r.flashcard_id, r.status;

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- BLOCK 2 — revert the fixture (run this AFTER live verification is done)
-- ─────────────────────────────────────────────────────────────────────────────────────────────
UPDATE public.reviews r
SET status = 'active'
FROM public.flashcards f
WHERE r.flashcard_id = f.id
  AND f.front_text = 'What is the maximum deduction under Section 80C?'
  AND r.status = 'mastered'
RETURNING r.user_id, r.flashcard_id, r.status;
