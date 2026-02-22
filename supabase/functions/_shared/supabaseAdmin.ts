import { createClient } from "npm:@supabase/supabase-js@2"

/**
 * Service-role Supabase client for Edge Functions.
 * Bypasses RLS — only use server-side, never expose to browser.
 */
export const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  { auth: { persistSession: false } }
)
