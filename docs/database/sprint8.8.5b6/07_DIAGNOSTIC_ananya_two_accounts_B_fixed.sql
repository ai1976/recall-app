-- [DIAGNOSTIC] Ananya two accounts - block B corrected (friendships uses user_id / friend_id). READ-ONLY.
-- Description: What each of her two accounts owns / has done. Paste the result table.
SELECT p.id, p.email,
  (SELECT count(*) FROM public.flashcards          x WHERE x.user_id = p.id) AS flashcards,
  (SELECT count(*) FROM public.notes               x WHERE x.user_id = p.id) AS notes,
  (SELECT count(*) FROM public.reviews             x WHERE x.user_id = p.id) AS reviews,
  (SELECT max(created_at) FROM public.reviews      x WHERE x.user_id = p.id) AS last_review,
  (SELECT count(*) FROM public.study_sessions      x WHERE x.user_id = p.id) AS study_sessions,
  (SELECT count(*) FROM public.my_cards_enrollment x WHERE x.user_id = p.id) AS my_study_enrollments,
  (SELECT count(*) FROM public.study_group_members x WHERE x.user_id = p.id) AS group_memberships,
  (SELECT count(*) FROM public.user_badges         x WHERE x.user_id = p.id) AS badges,
  (SELECT count(*) FROM public.friendships         x WHERE x.user_id = p.id OR x.friend_id = p.id) AS friendships
FROM public.profiles p
WHERE p.id IN ('38c343a1-5278-4dcb-bd04-1a66af523b1b', '0e3cd9a5-86c6-46db-a068-b266cf6af81e');
