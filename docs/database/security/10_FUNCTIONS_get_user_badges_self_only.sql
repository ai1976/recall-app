-- Name: [FUNCTIONS] Read-IDOR guard — get_user_badges self-only
-- Description: get_user_badges returns a user's FULL badge list INCLUDING private badges (is_public
-- flag, no filter) and took p_user_id with no auth.uid() check — a directly-callable REST endpoint,
-- so any authenticated user could read another user's private badges. The only live frontend caller
-- passes self (useBadges.js:34); the cross-user hook helper is dead code (removed in the same
-- change). Guard to self-or-admin. For viewing OTHERS' badges, get_public_user_badges (filters
-- is_public = true) is the correct RPC — left untouched. Body verbatim from 07 Block 2 + guard;
-- STABLE retained (guard reads only).

CREATE OR REPLACE FUNCTION public.get_user_badges(p_user_id uuid)
 RETURNS TABLE(badge_key text, badge_name text, description text, icon_key text, category text, earned_at timestamp with time zone, is_public boolean)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
      RAISE EXCEPTION 'Access denied: use get_public_user_badges to view another user''s badges';
    END IF;
    RETURN QUERY
    SELECT bd.key, bd.name, bd.description, bd.icon_key, bd.category, ub.earned_at, ub.is_public
    FROM user_badges ub
    JOIN badge_definitions bd ON bd.id = ub.badge_id
    WHERE ub.user_id = p_user_id
    ORDER BY ub.earned_at DESC;
END;
$function$;
