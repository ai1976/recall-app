/**
 * MigrateFlashcards.jsx — TEMPORARY admin utility
 *
 * Purpose: Migrate 162 flashcard images from base64 TEXT columns in the
 *          database to the `flashcard-images` Supabase Storage bucket.
 *
 * Why paginated: fetching all 162 base64 rows in one query = ~110 MB HTTP
 * response → Supabase API timeout. Instead we fetch 3 rows at a time
 * (≈1.7 MB per request) and process immediately.
 *
 * Safe to re-run: rows already containing Storage URLs are detected
 * client-side (startsWith check) and skipped automatically.
 *
 * Remove this file and its route from App.jsx once migration is confirmed.
 */

import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

const BUCKET = 'flashcard-images';
const PAGE_SIZE = 3; // rows fetched per HTTP request (keeps each response ≤ ~2 MB)

/** Convert a base64 data-URL to a Blob */
function base64ToBlob(dataUrl) {
  const [header, base64] = dataUrl.split(',');
  const mimeMatch = header.match(/:(.*?);/);
  const mime = mimeMatch ? mimeMatch[1] : 'image/jpeg';
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
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
  const [running, setRunning] = useState(false);
  const [done, setDone] = useState(false);
  // scanned = rows examined so far; total = candidate rows; processed/failed = base64 rows only
  const [stats, setStats] = useState({ total: 0, scanned: 0, processed: 0, failed: 0, skipped: 0 });
  const [logs, setLogs] = useState([]);

  const addLog = (msg, type = 'info') => {
    const ts = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { ts, msg, type }]);
  };

  const updateStats = (patch) => setStats(prev => ({ ...prev, ...patch }));

  /** Upload one side (front/back) of a card and return the public Storage URL, or null on failure */
  const uploadSide = async (cardId, side, dataUrl) => {
    try {
      const blob = base64ToBlob(dataUrl);
      const ext = mimeToExt(blob.type);
      const fileName = `migrated/${cardId}-${side}-${Date.now()}.${ext}`;

      const { error: uploadError } = await supabase.storage
        .from(BUCKET)
        .upload(fileName, blob, { upsert: true });

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from(BUCKET)
        .getPublicUrl(fileName);

      addLog(`  ✅ ${side}: uploaded → ${fileName}`, 'success');
      return publicUrl;
    } catch (err) {
      addLog(`  ❌ ${side}: ${err.message}`, 'error');
      return null;
    }
  };

  /** Migrate a single card. Returns true on full success. */
  const migrateCard = async (card) => {
    addLog(`📋 Card ${card.id}`);
    const patch = {};
    let anyFailed = false;

    if (card.front_image_url?.startsWith('data:')) {
      const url = await uploadSide(card.id, 'front', card.front_image_url);
      if (url) patch.front_image_url = url;
      else anyFailed = true;
    }

    if (card.back_image_url?.startsWith('data:')) {
      const url = await uploadSide(card.id, 'back', card.back_image_url);
      if (url) patch.back_image_url = url;
      else anyFailed = true;
    }

    if (Object.keys(patch).length === 0) return !anyFailed;

    const { error: updateError } = await supabase
      .from('flashcards')
      .update(patch)
      .eq('id', card.id);

    if (updateError) {
      addLog(`  ❌ DB update failed: ${updateError.message}`, 'error');
      return false;
    }

    return !anyFailed;
  };

  const runMigration = async () => {
    setRunning(true);
    setDone(false);
    setLogs([]);
    setStats({ total: 0, scanned: 0, processed: 0, failed: 0, skipped: 0 });

    // ── Step 1: Fast count using NULL check only ────────────────────────────
    // NULL check does NOT load large TOAST column values → very fast.
    // We filter by back_image_url because diagnostic confirmed all 162 images
    // are on the back side. Front is also checked client-side for safety.
    addLog('🔍 Counting candidate rows (NULL check — fast)…');

    const { count: total, error: countError } = await supabase
      .from('flashcards')
      .select('*', { count: 'exact', head: true })
      .not('back_image_url', 'is', null);

    if (countError) {
      addLog(`❌ Count failed: ${countError.message}`, 'error');
      setRunning(false);
      return;
    }

    if (total === 0) {
      addLog('🎉 No rows with image data found — nothing to migrate!', 'success');
      setDone(true);
      setRunning(false);
      return;
    }

    addLog(`📊 ${total} candidate row(s) — fetching ${PAGE_SIZE} at a time…`);
    updateStats({ total });

    // ── Step 2: Paginated fetch + process ──────────────────────────────────
    let scanned = 0;
    let processed = 0;
    let failed = 0;
    let skipped = 0; // rows already using Storage URLs

    for (let page = 0; page * PAGE_SIZE < total; page++) {
      const from = page * PAGE_SIZE;
      const to = from + PAGE_SIZE - 1;

      const { data: batch, error: fetchError } = await supabase
        .from('flashcards')
        .select('id, front_image_url, back_image_url')
        .not('back_image_url', 'is', null)
        .order('id')          // stable ordering for consistent pagination
        .range(from, to);     // only PAGE_SIZE rows per HTTP response

      if (fetchError) {
        addLog(`❌ Fetch error at offset ${from}: ${fetchError.message}`, 'error');
        break;
      }

      if (!batch || batch.length === 0) break;

      scanned += batch.length;
      updateStats({ scanned });

      for (const card of batch) {
        const hasFrontBase64 = card.front_image_url?.startsWith('data:');
        const hasBackBase64  = card.back_image_url?.startsWith('data:');

        if (!hasFrontBase64 && !hasBackBase64) {
          // Already a Storage URL — skip silently
          skipped++;
          updateStats({ skipped });
          continue;
        }

        const ok = await migrateCard(card);
        if (ok) processed++;
        else failed++;
        updateStats({ processed, failed });
      }
    }

    // ── Done ────────────────────────────────────────────────────────────────
    const summary = `${processed} migrated, ${failed} failed, ${skipped} already done`;
    addLog(
      `\n🏁 Complete — ${summary}.`,
      failed > 0 ? 'error' : 'success'
    );
    setDone(true);
    setRunning(false);
  };

  const pct = stats.total > 0
    ? Math.round((stats.scanned / stats.total) * 100)
    : 0;

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
            One-time admin utility — moves base64 images from the database into
            the <code>flashcard-images</code> Storage bucket.
          </p>
        </div>

        {/* Pre-flight checklist */}
        <Card className="border-amber-200 bg-amber-50">
          <CardHeader>
            <CardTitle className="text-amber-800 text-base">⚠️ Before you start</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-amber-800 space-y-1">
            <p>1. The <strong>flashcard-images</strong> bucket must exist in Supabase Storage (Public ON).</p>
            <p>2. RLS policies must allow authenticated writes to the <code>migrated/</code> prefix.</p>
            <p>3. Safe to re-run — already-migrated rows (Storage URLs) are detected and skipped.</p>
            <p>4. Expected time: ~3–6 minutes for 162 images (network dependent).</p>
            <p>5. Delete this page and its route from <code>App.jsx</code> after confirming success.</p>
          </CardContent>
        </Card>

        {/* Controls */}
        <Card>
          <CardContent className="pt-6 space-y-4">
            <Button
              onClick={runMigration}
              disabled={running}
              className="w-full"
              size="lg"
            >
              {running ? 'Migration in progress…' : done ? '🔄 Run Again' : '🚀 Start Migration'}
            </Button>

            {/* Progress bar — tracks rows scanned vs total */}
            {(running || done) && stats.total > 0 && (
              <div className="space-y-1">
                <div className="flex justify-between text-sm text-muted-foreground">
                  <span>Scanning rows</span>
                  <span>{stats.scanned} / {stats.total} ({pct}%)</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2.5">
                  <div
                    className={`h-2.5 rounded-full transition-all ${stats.failed > 0 ? 'bg-amber-500' : 'bg-primary'}`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
                  <span className="text-green-600">✅ {stats.processed} migrated</span>
                  {stats.failed > 0 && <span className="text-red-600">❌ {stats.failed} failed</span>}
                  {stats.skipped > 0 && <span className="text-gray-500">⏭ {stats.skipped} already done</span>}
                  <span>📦 {stats.total} total rows</span>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Log panel */}
        {logs.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-base font-mono">Migration Log</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="bg-gray-900 text-gray-100 rounded-lg p-4 h-80 overflow-y-auto font-mono text-xs space-y-0.5">
                {logs.map((entry, i) => (
                  <div
                    key={i}
                    className={
                      entry.type === 'error'
                        ? 'text-red-400'
                        : entry.type === 'success'
                          ? 'text-green-400'
                          : 'text-gray-300'
                    }
                  >
                    <span className="text-gray-500">[{entry.ts}]</span> {entry.msg}
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}

        {done && stats.failed === 0 && (
          <Card className="border-green-200 bg-green-50">
            <CardContent className="pt-6 text-sm text-green-800">
              <p className="font-semibold">🎉 Migration successful!</p>
              <p className="mt-1">
                All {stats.processed} image(s) moved to Storage.
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
