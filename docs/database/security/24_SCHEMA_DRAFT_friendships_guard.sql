-- Name: [SCHEMA] DRAFT - friendships write guard (BEFORE INSERT OR UPDATE trigger)   *** DO NOT DEPLOY YET ***
-- Status: DRAFT. Deploy only after 22 (catalog facts) and 23 (proof) show the hole is real AND after the
--   INSERT/DELETE policies from 22 block A have been read (the guard is written to be correct whatever
--   they say, but the report must match reality).
-- Description: Today either party can UPDATE any column of a friendship row (policy "Users can update their
--   own friendships": auth.uid() = user_id OR auth.uid() = friend_id, no WITH CHECK), and both accept paths
--   (FriendRequests.jsx handleAccept, NotificationCenter.jsx accept) send a bare
--   UPDATE ... SET status='accepted' WHERE id = ... with no recipient check - so RLS is the only gate.
--   An accepted friendship unlocks friends-visibility content (users_view_friends_notes/flashcards, the
--   get_study_queue / add_to_my_cards friend predicates) and feeds the social badge counters.
--
--   Rules for DIRECT CLIENT writes only (current_user IN ('authenticated','anon'); SECURITY INVOKER so
--   SECURITY DEFINER functions, service_role and the SQL editor are unconstrained - same mechanism as
--   19_SCHEMA_profiles_protected_columns_guard.sql):
--     INSERT: the sender must be the caller, and a new request must be 'pending'.
--     UPDATE: user_id and friend_id are immutable (no retargeting a row at someone else);
--             ->'accepted': only the RECIPIENT, and only from 'pending';
--             ->'rejected': only the recipient;
--             ->'pending' : only the sender (re-send after a rejection), never downgrading 'accepted'.
--     DELETE is untouched (unfriend / decline-by-delete keep working).
--   Every legitimate flow in the app fits these rules:
--     send = UPSERT (user_id=caller, friend_id=X, status='pending'); accept/decline = recipient UPDATE;
--     reject-by-delete = DELETE.

CREATE OR REPLACE FUNCTION public.fn_guard_friendships_client_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Not permitted: a friend request must be sent as yourself' USING ERRCODE = '42501';
    END IF;
    IF NEW.status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION 'Not permitted: a new friend request must be pending' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.friend_id IS DISTINCT FROM OLD.friend_id THEN
    RAISE EXCEPTION 'Not permitted: the parties of a friendship cannot be changed' USING ERRCODE = '42501';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'accepted' THEN
      IF auth.uid() IS DISTINCT FROM OLD.friend_id OR OLD.status IS DISTINCT FROM 'pending' THEN
        RAISE EXCEPTION 'Not permitted: only the recipient can accept a pending request' USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.status = 'rejected' THEN
      IF auth.uid() IS DISTINCT FROM OLD.friend_id THEN
        RAISE EXCEPTION 'Not permitted: only the recipient can reject a request' USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.status = 'pending' THEN
      IF auth.uid() IS DISTINCT FROM OLD.user_id OR OLD.status = 'accepted' THEN
        RAISE EXCEPTION 'Not permitted: only the sender can re-send, and never over an accepted friendship' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_friendships_client_writes ON public.friendships;

CREATE TRIGGER trg_guard_friendships_client_writes
  BEFORE INSERT OR UPDATE ON public.friendships
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_guard_friendships_client_writes();

-- Trigger ordering note: the existing AFTER triggers (trg_aaa_counter_friendships, trg_badge_friendship) are
-- unaffected; this guard fires BEFORE them, so a refused write never reaches the counters/badges.
