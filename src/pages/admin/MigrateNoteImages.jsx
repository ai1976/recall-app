/**
 * TEMPORARY ADMIN PAGE — DELETE AFTER USE
 * Compresses oversized note images in-place in the 'notes' Storage bucket.
 * Route: /admin/migrate-note-images
 *
 * REMOVAL CHECKLIST (after migration is confirmed complete):
 *   1. Delete this file
 *   2. Remove the import and <Route> from App.jsx
 *   3. Run `npx vite build` to confirm no errors
 */

import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import imageCompression from 'browser-image-compression';

const COMPRESSION_OPTIONS = {
  maxSizeMB: 0.3,
  maxWidthOrHeight: 1920,
  useWebWorker: true,
};

// Images at or below this size are already small enough — skip them.
// Target is 300 KB; 400 KB gives a buffer to avoid recompressing near-target images.
const SKIP_BELOW_BYTES = 400 * 1024;

/**
 * Extracts the Storage object path from a Supabase public URL.
 * URL format: https://xxx.supabase.co/storage/v1/object/public/notes/{path}
 * Returns null if the URL doesn't match the expected pattern.
 */
function extractStoragePath(publicUrl) {
  const marker = '/object/public/notes/';
  const idx = publicUrl.indexOf(marker);
  if (idx === -1) return null;
  return decodeURIComponent(publicUrl.slice(idx + marker.length).split('?')[0]);
}

/**
 * Returns false for PDFs (which we cannot compress with browser-image-compression).
 */
function isImagePath(path) {
  return !path.toLowerCase().endsWith('.pdf');
}

export default function MigrateNoteImages() {
  const [status, setStatus] = useState('idle'); // idle | running | done
  const [log, setLog] = useState([]);
  const [stats, setStats] = useState({
    total: 0,
    processed: 0,
    compressed: 0,
    skipped: 0,
    failed: 0,
  });

  const addLog = (msg, type = 'info') => {
    setLog(prev => [...prev, { msg, type }]);
  };

  const run = async () => {
    setStatus('running');
    setLog([]);
    setStats({ total: 0, processed: 0, compressed: 0, skipped: 0, failed: 0 });

    // ─── Phase 1: Fetch IDs only ─────────────────────────────────────────────
    // IS NOT NULL reads only the null-flag in the heap tuple — zero TOAST load.
    addLog('Phase 1: Fetching note IDs with image_url IS NOT NULL...');

    const { data: idRows, error: idError } = await supabase
      .from('notes')
      .select('id')
      .not('image_url', 'is', null);

    if (idError) {
      addLog(`Error fetching IDs: ${idError.message}`, 'error');
      setStatus('done');
      return;
    }

    const ids = idRows.map(r => r.id);
    setStats(s => ({ ...s, total: ids.length }));
    addLog(`Found ${ids.length} notes with image_url. Processing one at a time...`);

    // ─── Phase 2: Process one row at a time ──────────────────────────────────
    let compressed = 0;
    let skipped = 0;
    let failed = 0;

    for (let i = 0; i < ids.length; i++) {
      const id = ids[i];
      const prefix = `[${i + 1}/${ids.length}]`;

      try {
        // One TOAST decompression per iteration — safe
        const { data: note, error: fetchError } = await supabase
          .from('notes')
          .select('id, image_url, title')
          .eq('id', id)
          .single();

        if (fetchError) throw fetchError;

        // Guard: image_url could have been cleared between phase 1 and now
        if (!note.image_url) {
          addLog(`${prefix} ⏭ SKIP (image_url cleared): ${id}`);
          skipped++;
          setStats(s => ({ ...s, processed: i + 1, skipped }));
          continue;
        }

        // Extract path from Storage public URL
        const storagePath = extractStoragePath(note.image_url);

        if (!storagePath) {
          addLog(`${prefix} ⏭ SKIP (not a Storage URL): ${note.image_url.slice(0, 80)}`);
          skipped++;
          setStats(s => ({ ...s, processed: i + 1, skipped }));
          continue;
        }

        // Skip PDFs — browser-image-compression cannot handle them
        if (!isImagePath(storagePath)) {
          addLog(`${prefix} ⏭ SKIP (PDF): ${note.title || id}`);
          skipped++;
          setStats(s => ({ ...s, processed: i + 1, skipped }));
          continue;
        }

        // Download from Storage
        const { data: blob, error: downloadError } = await supabase.storage
          .from('notes')
          .download(storagePath);

        if (downloadError) throw new Error(`Download failed: ${downloadError.message}`);

        const originalKB = Math.round(blob.size / 1024);

        // Skip if already small enough
        if (blob.size <= SKIP_BELOW_BYTES) {
          addLog(`${prefix} ⏭ SKIP (already ${originalKB} KB): ${note.title || id}`);
          skipped++;
          setStats(s => ({ ...s, processed: i + 1, skipped }));
          continue;
        }

        // Wrap Blob in a File so imageCompression accepts it
        const ext = storagePath.split('.').pop() || 'jpg';
        const fileForCompression = new File(
          [blob],
          `note.${ext}`,
          { type: blob.type || 'image/jpeg' }
        );

        // Compress client-side
        const compressedBlob = await imageCompression(fileForCompression, COMPRESSION_OPTIONS);
        const compressedKB = Math.round(compressedBlob.size / 1024);
        const savedPct = Math.round((1 - compressedBlob.size / blob.size) * 100);

        // Re-upload to the same path (upsert: true overwrites the original)
        const { error: uploadError } = await supabase.storage
          .from('notes')
          .upload(storagePath, compressedBlob, {
            upsert: true,
            contentType: compressedBlob.type,
          });

        if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

        // The public URL hasn't changed — no DB update needed.
        addLog(
          `${prefix} ✅ ${originalKB} KB → ${compressedKB} KB (${savedPct}% saved): ${note.title || id}`,
          'success'
        );
        compressed++;
        setStats(s => ({ ...s, processed: i + 1, compressed }));

      } catch (err) {
        addLog(`${prefix} ❌ FAILED (${id}): ${err.message}`, 'error');
        failed++;
        setStats(s => ({ ...s, processed: i + 1, failed }));
      }
    }

    setStatus('done');
    addLog(
      `─── Done: ${compressed} compressed, ${skipped} skipped, ${failed} failed ───`,
      'info'
    );
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-3xl mx-auto space-y-6">

        <div>
          <h1 className="text-2xl font-bold text-gray-900">Migrate Note Images</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Compresses oversized note images in the <code>notes</code> Storage bucket.
            Skips PDFs and images already ≤ 400 KB. Re-uploads in-place (same path, upsert)
            — no DB changes required.
          </p>
          <p className="text-sm text-red-600 font-semibold mt-2">
            Delete this page and its App.jsx route immediately after migration is confirmed.
          </p>
        </div>

        {status === 'idle' && (
          <button
            onClick={run}
            className="bg-indigo-600 text-white px-6 py-2 rounded-lg hover:bg-indigo-700 font-medium"
          >
            Start Migration
          </button>
        )}

        {status !== 'idle' && (
          <div className="text-sm font-mono bg-white border rounded-lg px-4 py-3 grid grid-cols-5 gap-2 text-center">
            <div><div className="text-gray-500 text-xs">Total</div><div className="font-bold">{stats.total}</div></div>
            <div><div className="text-gray-500 text-xs">Processed</div><div className="font-bold">{stats.processed}</div></div>
            <div><div className="text-green-600 text-xs">Compressed</div><div className="font-bold text-green-600">{stats.compressed}</div></div>
            <div><div className="text-gray-500 text-xs">Skipped</div><div className="font-bold">{stats.skipped}</div></div>
            <div><div className="text-red-500 text-xs">Failed</div><div className="font-bold text-red-500">{stats.failed}</div></div>
          </div>
        )}

        <div className="font-mono text-xs bg-gray-900 text-gray-100 rounded-lg p-4 h-96 overflow-y-auto space-y-0.5">
          {log.length === 0 && status === 'idle' && (
            <span className="text-gray-500">Waiting to start…</span>
          )}
          {log.map((entry, i) => (
            <div
              key={i}
              className={
                entry.type === 'success' ? 'text-green-400' :
                entry.type === 'error'   ? 'text-red-400'   :
                'text-gray-300'
              }
            >
              {entry.msg}
            </div>
          ))}
          {status === 'running' && (
            <div className="text-yellow-400 animate-pulse">Processing…</div>
          )}
          {status === 'done' && (
            <div className="text-blue-400 mt-2">Migration complete. Scroll up to review failures.</div>
          )}
        </div>

      </div>
    </div>
  );
}
