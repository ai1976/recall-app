# Runbook - changing a user's login email (super admin recovery)

**Who may do this:** the Super Admin only (Anand). NOT the plain Admin role (Shailaja) and not any future institute Admin until B2B
scoping exists (D-50). Changing a login email is an identity-control operation: whoever controls the mailbox can reset the
password and take over the account.

## Normal case - the user does it themselves
Profile Settings -> **Change email**. Supabase sends a confirmation link to BOTH the current and the new address (Secure email change
is ON); the login email changes only after both links are opened. Nothing for staff to do.

## Exceptional case - the user cannot reach the old mailbox, or typed it wrong at signup
1. **Verify identity first** (outside the app): e.g. call/message the student on the number you already have for them, confirm
   their full name, batch and a recent activity only they would know. Do not act on an email request alone.
2. Supabase Dashboard -> **Authentication -> Users** -> open the user -> edit the **email** -> save. (Use the all-lowercase address.)
3. Nothing else is needed: the database trigger `trg_sync_profile_email_from_auth` updates `profiles.email` and writes an
   `email_changed` entry to the admin audit log (mechanism `dashboard_or_admin`, no admin actor recorded for a dashboard change).
4. Tell the student to log in with the new address; if they do not remember the password, use **Forgot password** on the new address.
5. If the save fails with a duplicate error, the address already belongs to another account - do not force it.

## Checks
- Audit trail: Super Admin Dashboard -> Audit Log -> `email_changed` (old + new address).
- Never edit `profiles.email` directly: it is guarded (D-45) and must follow Auth.
