-- [DIAGNOSTIC] Ananya Bhagwat has TWO accounts - what does each one hold? (01/10/2026). READ-ONLY.
-- Description: Block B of 05 showed her Gmail address already belongs to profile 38c343a1... ("Ananya", created 05/03/2026),
--   so Supabase refused to give it to her newer account 0e3cd9a5... (created 28/07/2026). Before anyone decides what to do, this
--   compares what each account owns. Run each block and paste the results. Nothing here changes data.

-- A. Both logins (corrected: this Auth version has no new_email column)
SELECT id, email, email_confirmed_at, created_at, last_sign_in_at, email_change, email_change_sent_at
FROM auth.users
WHERE id IN ('38c343a1-5278-4dcb-bd04-1a66af523b1b', '0e3cd9a5-86c6-46db-a068-b266cf6af81e')
ORDER BY created_at;

-- B. What each account owns / has done
SELECT p.id, p.email,
  (SELECT count(*) FROM public.flashcards       x WHERE x.user_id = p.id) AS flashcards,
  (SELECT count(*) FROM public.notes            x WHERE x.user_id = p.id) AS notes,
  (SELECT count(*) FROM public.reviews          x WHERE x.user_id = p.id) AS reviews,
  (SELECT max(created_at) FROM public.reviews   x WHERE x.user_id = p.id) AS last_review,
  (SELECT count(*) FROM public.study_sessions   x WHERE x.user_id = p.id) AS study_sessions,
  (SELECT count(*) FROM public.my_cards_enrollment x WHERE x.user_id = p.id) AS my_study_enrollments,
  (SELECT count(*) FROM public.study_group_members x WHERE x.user_id = p.id) AS group_memberships,
  (SELECT count(*) FROM public.user_badges      x WHERE x.user_id = p.id) AS badges,
  (SELECT count(*) FROM public.friendships      x WHERE x.requester_id = p.id OR x.addressee_id = p.id) AS friendships
FROM public.profiles p
WHERE p.id IN ('38c343a1-5278-4dcb-bd04-1a66af523b1b', '0e3cd9a5-86c6-46db-a068-b266cf6af81e');

-- C. Profile details side by side (course, institution)
SELECT id, full_name, email, course_level, institution, created_at
FROM public.profiles
WHERE id IN ('38c343a1-5278-4dcb-bd04-1a66af523b1b', '0e3cd9a5-86c6-46db-a068-b266cf6af81e');
