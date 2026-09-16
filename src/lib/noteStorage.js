import { supabase } from '@/lib/supabase';

// URL format: https://xxx.supabase.co/storage/v1/object/public/notes/{path}
export function extractNoteStoragePath(imageUrl) {
  if (!imageUrl) return null;
  const match = imageUrl.match(/\/notes\/(.+)$/);
  return match ? match[1] : null;
}

// Best-effort cleanup — a failed removal here must not block a note delete
// that has already succeeded, so this only warns rather than throwing.
export async function deleteNoteStorageImage(imageUrl) {
  const path = extractNoteStoragePath(imageUrl);
  if (!path) return;

  const { error } = await supabase.storage.from('notes').remove([path]);
  if (error) {
    console.warn('Failed to delete note image from storage:', error);
  }
}
