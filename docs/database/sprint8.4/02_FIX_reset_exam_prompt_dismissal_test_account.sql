-- [FIX] Reset exam-date prompt dismissal on test account
-- Description: Resets has_dismissed_exam_prompt, exam_date, and exam_month back
-- to their pristine pre-Sprint-8.4 state (false/NULL/NULL) on the TestOutlook
-- test profile only, so the first-login popup's dismiss lifecycle can be
-- verified end-to-end (D-17 extension audit, 16/09/2026): popup reappears when
-- unset -> dismiss without setting -> survives reload/login (never reappears)
-- -> nav chip/Profile Settings route stay reachable regardless of the dismiss
-- flag -> setting an exam date afterward remains clean. Scoped by email so it
-- only ever touches this one disposable test account. Safe to rerun.

UPDATE profiles
SET has_dismissed_exam_prompt = false,
    exam_date = NULL,
    exam_month = NULL
WHERE email = 'anandmore@outlook.com';
