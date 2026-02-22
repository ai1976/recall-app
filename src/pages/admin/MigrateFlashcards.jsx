/**
 * MigrateFlashcards.jsx — TEMPORARY admin utility
 *
 * Purpose: Migrate 162 flashcard images from base64 TEXT columns to
 *          the `flashcard-images` Supabase Storage bucket.
 *
 * Why row-by-row: The back_image_url column stores large TOAST values
 * (~570 KB each). Any query that touches those values (LIKE, substring,
 * select *) forces PostgreSQL to decompress 92 MB → timeout.
 *
 * Strategy used here:
 *   Step 1 — SELECT id WHERE back_image_url IS NOT NULL
 *             IS NOT NULL only reads the null-flag in the heap tuple.
 *             No TOAST loading. Returns ~162 UUIDs in milliseconds.
 *   Step 2 — For each ID: SELECT that one row individually.
 *             One TOAST value (~570 KB) per request. Fast per request.
 *             startsWith('data:') check is client-side — no DB scan.
 *
 * Safe to re-run: rows already using Storage URLs are skipped client-side.
 * Delete this file and its App.jsx route after confirming success.
 */

import { useState, useRef } from 'react';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

const BUCKET = 'flashcard-images';

/** Convert a base64 data-URL string → Blob */
function base64ToBlob(dataUrl) {
  const [header, base64] = dataUrl.split(',');
  const mimeMatch = header.match(/:(.*?);/);
  const mime = mimeMatch ? mimeMatch[1] : 'image/jpeg';
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mime });
}

function mimeToExt(mime) {
  if (mime.includes('png')) return 'png';
  if (mime.includes('gif')) return 'gif';
  if (mime.includes('webp')) return 'webp';
  return 'jpg';
}

export default function MigrateFlashcards() {
  const navigate = useNavigate();
  const logRef = useRef(null);

  const [running, setRunning] = useState(false);
  const [done, setDone] = useState(false);
  const [stats, setStats] = useState({ total: 0, scanned: 0, migrated: 0, skipped: 0, failed: 0 });
  const [logs, setLogs] = useState([]);

  const addLog = (msg, type = 'info') => {
    const ts = new Date().toLocaleTimeString();
    setLogs(prev => {
      const next = [...prev, { ts, msg, type }];
      // Auto-scroll log panel
      setTimeout(() => logRef.current?.scrollTo({ top: logRef.current.scrollHeight, behavior: 'smooth' }), 30);
      return next;
    });
  };

  const patch = (p) => setStats(prev => ({ ...prev, ...p }));

  /** Upload one side of a card to Storage. Returns public URL or null. */
  const uploadSide = async (cardId, side, dataUrl) => {
    try {
      const blob = base64ToBlob(dataUrl);
      const ext = mimeToExt(blob.type);
      const fileName = `migrated/${cardId}-${side}-${Date.now()}.${ext}`;

      const { error: upErr } = await supabase.storage
        .from(BUCKET)
        .upload(fileName, blob, { upsert: true });
      if (upErr) throw upErr;

      const { data: { publicUrl } } = supabase.storage.from(BUCKET).getPublicUrl(fileName);
      addLog(`  ✅ ${side} → ${fileName}`, 'success');
      return publicUrl;
    } catch (err) {
      addLog(`  ❌ ${side} upload failed: ${err.message}`, 'error');
      return null;
    }
  };

  /** Migrate front and/or back images for one card. Returns 'migrated' | 'skipped' | 'failed'. */
  const processCard = async (card) => {
    const hasFront = card.front_image_url?.startsWith('data:');
    const hasBack  = card.back_image_url?.startsWith('data:');

    if (!hasFront && !hasBack) return 'skipped'; // already a Storage URL

    addLog(`📋 Card ${card.id}`);
    const update = {};
    let anyFailed = false;

    if (hasFront) {
      const url = await uploadSide(card.id, 'front', card.front_image_url);
      if (url) update.front_image_url = url;
      else anyFailed = true;
    }
    if (hasBack) {
      const url = await uploadSide(card.id, 'back', card.back_image_url);
      if (url) update.back_image_url = url;
      else anyFailed = true;
    }

    if (Object.keys(update).length > 0) {
      const { error: dbErr } = await supabase.from('flashcards').update(update).eq('id', card.id);
      if (dbErr) {
        addLog(`  ❌ DB update failed: ${dbErr.message}`, 'error');
        return 'failed';
      }
    }

    return anyFailed ? 'failed' : 'migrated';
  };

  const runMigration = async () => {
    setRunning(true);
    setDone(false);
    setLogs([]);
    setStats({ total: 0, scanned: 0, migrated: 0, skipped: 0, failed: 0 });

    // ── STEP 1: Get IDs only ──────────────────────────────────────────────
    // SELECT id WHERE IS NOT NULL → reads only null-flags in heap, never TOAST.
    // Returns ~162 small UUIDs. Should complete in < 1 second.
    addLog('🔍 Step 1 — Fetching candidate IDs (IS NOT NULL, no TOAST load)…');

    const { data: idRows, error: idErr } = await supabase
      .from('flashcards')
      .select('id')                          // ← id only, avoids touching TOAST
      .not('back_image_url', 'is', null)     // ← IS NOT NULL = null-flag check only
      .order('id');

    if (idErr) {
      addLog(`❌ ID fetch failed: ${idErr.message}`, 'error');
      setRunning(false);
      return;
    }

    const ids = idRows?.map(r => r.id) ?? [];
    const total = ids.length;
    addLog(`📊 ${total} candidate row(s) found. Starting row-by-row migration…`);
    patch({ total });

    if (total === 0) {
      addLog('🎉 Nothing to migrate!', 'success');
      setDone(true);
      setRunning(false);
      return;
    }

    // ── STEP 2: Fetch + process ONE row at a time ─────────────────────────
    // Each individual SELECT loads exactly one TOAST value (~570 KB).
    // startsWith('data:') check is client-side — no LIKE in DB at all.
    let scanned = 0, migrated = 0, skipped = 0, failed = 0;

    for (const id of ids) {
      // Fetch one full row — one TOAST decompression, manageable
      const { data: card, error: rowErr } = await supabase
        .from('flashcards')
        .select('id, front_image_url, back_image_url')
        .eq('id', id)
        .single();

      scanned++;

      if (rowErr || !card) {
        addLog(`❌ Row ${id}: fetch error — ${rowErr?.message ?? 'null'}`, 'error');
        failed++;
        patch({ scanned, failed });
        continue;
      }

      const result = await processCard(card);
      if (result === 'migrated') migrated++;
      else if (result === 'skipped') skipped++;
      else failed++;

      patch({ scanned, migrated, skipped, failed });
    }

    // ── Done ──────────────────────────────────────────────────────────────
    addLog(
      `\n🏁 Complete — ${migrated} migrated, ${skipped} skipped, ${failed} failed.`,
      failed > 0 ? 'error' : 'success'
    );
    setDone(true);
    setRunning(false);
  };

  const pct = stats.total > 0 ? Math.round((stats.scanned / stats.total) * 100) : 0;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">

        <Button variant="ghost" onClick={() => navigate(-1)} className="mb-2">
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back
        </Button>

        <div>
          <h1 className="text-3xl font-bold">Migrate Flashcard Images</h1>
          <p className="text-muted-foreground mt-1">
            One-time utility — moves base64 images from the database into
            the <code>flashcard-images</code> Storage bucket.
          </p>
        </div>

        {/* Info */}
        <Card className="border-blue-200 bg-blue-50">
          <CardContent className="pt-4 text-sm text-blue-800 space-y-1">
            <p><strong>How it works:</strong> Fetches only IDs first (fast), then loads one row at a time to avoid TOAST timeouts.</p>
            <p><strong>Expected time:</strong> ~3–5 minutes for 162 images.</p>
            <p><strong>Safe to re-run</strong> — already-migrated rows are detected and skipped.</p>
          </CardContent>
        </Card>

        {/* Pre-flight */}
        <Card className="border-amber-200 bg-amber-50">
          <CardHeader>
            <CardTitle className="text-amber-800 text-base">⚠️ Pre-flight checklist</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-amber-800 space-y-1">
            <p>1. <strong>flashcard-images</strong> bucket exists in Supabase Storage (Public ON).</p>
            <p>2. RLS policies allow authenticated writes to the <code>migrated/</code> prefix.</p>
            <p>3. Do not close or refresh this tab while migration is running.</p>
            <p>4. Delete this page + its route from <code>App.jsx</code> after success.</p>
          </CardContent>
        </Card>

        {/* Button + progress */}
        <Card>
          <CardContent className="pt-6 space-y-4">
            <Button onClick={runMigration} disabled={running} className="w-full" size="lg">
              {running ? 'Migration in progress…' : done ? '🔄 Run Again' : '🚀 Start Migration'}
            </Button>

            {(running || done) && stats.total > 0 && (
              <div className="space-y-1">
                <div className="flex justify-between text-sm text-muted-foreground">
                  <span>Rows processed</span>
                  <span>{stats.scanned} / {stats.total} ({pct}%)</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2.5">
                  <div
                    className={`h-2.5 rounded-full transition-all duration-300 ${stats.failed > 0 ? 'bg-amber-500' : 'bg-primary'}`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs">
                  <span className="text-green-600">✅ {stats.migrated} migrated</span>
                  <span className="text-gray-500">⏭ {stats.skipped} already done</span>
                  {stats.failed > 0 && <span className="text-red-600">❌ {stats.failed} failed</span>}
                  <span className="text-muted-foreground">📦 {stats.total} total</span>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Log */}
        {logs.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-base font-mono">Migration Log</CardTitle>
            </CardHeader>
            <CardContent>
              <div
                ref={logRef}
                className="bg-gray-900 text-gray-100 rounded-lg p-4 h-80 overflow-y-auto font-mono text-xs space-y-0.5"
              >
                {logs.map((e, i) => (
                  <div
                    key={i}
                    className={
                      e.type === 'error' ? 'text-red-400'
                      : e.type === 'success' ? 'text-green-400'
                      : 'text-gray-300'
                    }
                  >
                    <span className="text-gray-500">[{e.ts}]</span> {e.msg}
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}

        {done && stats.failed === 0 && (
          <Card className="border-green-200 bg-green-50">
            <CardContent className="pt-6 text-sm text-green-800">
              <p className="font-semibold">🎉 Migration complete!</p>
              <p className="mt-1">
                {stats.migrated} image(s) moved to Storage, {stats.skipped} already done.
                You can now delete <code>src/pages/admin/MigrateFlashcards.jsx</code> and
                remove its import + route from <code>src/App.jsx</code>.
              </p>
            </CardContent>
          </Card>
        )}

      </div>
    </div>
  );
}
