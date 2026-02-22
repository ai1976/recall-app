/**
 * MigrateFlashcards.jsx — TEMPORARY admin utility
 *
 * Purpose: Migrate 162 flashcard images from base64 TEXT columns in the
 *          database to the `flashcard-images` Supabase Storage bucket.
 *
 * Safe to re-run: uploads use unique timestamps, so duplicate runs create
 * new files but do not corrupt existing data. Old Storage files can be
 * cleaned up manually after confirming the migration.
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
const BATCH_SIZE = 3; // process N cards concurrently

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
  const [stats, setStats] = useState({ total: 0, processed: 0, failed: 0 });
  const [logs, setLogs] = useState([]);

  const addLog = (msg, type = 'info') => {
    const ts = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { ts, msg, type }]);
  };

  const updateStats = (patch) => setStats(prev => ({ ...prev, ...patch }));

  const migrateCard = async (card) => {
    const results = [];

    for (const side of ['front', 'back']) {
      const col = `${side}_image_url`;
      const raw = card[col];
      if (!raw || !raw.startsWith('data:')) continue;

      try {
        const blob = base64ToBlob(raw);
        const ext = mimeToExt(blob.type);
        const fileName = `migrated/${card.id}-${side}-${Date.now()}.${ext}`;

        const { error: uploadError } = await supabase.storage
          .from(BUCKET)
          .upload(fileName, blob, { upsert: true });

        if (uploadError) throw uploadError;

        const { data: { publicUrl } } = supabase.storage
          .from(BUCKET)
          .getPublicUrl(fileName);

        results.push({ col, publicUrl });
        addLog(`✅ Card ${card.id} | ${side}: uploaded → ${fileName}`, 'success');
      } catch (err) {
        addLog(`❌ Card ${card.id} | ${side}: ${err.message}`, 'error');
        return false; // signal partial/full failure for this card
      }
    }

    if (results.length === 0) return true; // nothing to migrate on this card

    // Update DB row with Storage URLs
    const patch = {};
    for (const { col, publicUrl } of results) {
      patch[col] = publicUrl;
    }

    const { error: updateError } = await supabase
      .from('flashcards')
      .update(patch)
      .eq('id', card.id);

    if (updateError) {
      addLog(`❌ Card ${card.id} | DB update failed: ${updateError.message}`, 'error');
      return false;
    }

    return true;
  };

  const runMigration = async () => {
    setRunning(true);
    setDone(false);
    setLogs([]);
    setStats({ total: 0, processed: 0, failed: 0 });

    addLog('🔍 Fetching flashcards with base64 images…');

    // Fetch all cards where either image column contains base64
    const { data: cards, error: fetchError } = await supabase
      .from('flashcards')
      .select('id, front_image_url, back_image_url')
      .or('front_image_url.like.data:%,back_image_url.like.data:%');

    if (fetchError) {
      addLog(`❌ Fetch error: ${fetchError.message}`, 'error');
      setRunning(false);
      return;
    }

    const total = cards?.length ?? 0;
    addLog(`📊 Found ${total} flashcard(s) with base64 images.`);
    updateStats({ total });

    if (total === 0) {
      addLog('🎉 Nothing to migrate! All images already in Storage.', 'success');
      setDone(true);
      setRunning(false);
      return;
    }

    let processed = 0;
    let failed = 0;

    // Process in batches of BATCH_SIZE
    for (let i = 0; i < cards.length; i += BATCH_SIZE) {
      const batch = cards.slice(i, i + BATCH_SIZE);
      const results = await Promise.all(batch.map(card => migrateCard(card)));

      for (const ok of results) {
        if (ok) processed++;
        else failed++;
      }

      updateStats({ processed, failed });
    }

    addLog(
      `\n🏁 Migration complete — ${processed} succeeded, ${failed} failed out of ${total}.`,
      failed > 0 ? 'error' : 'success'
    );
    setDone(true);
    setRunning(false);
  };

  const pct = stats.total > 0
    ? Math.round(((stats.processed + stats.failed) / stats.total) * 100)
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
            <p>1. The <strong>flashcard-images</strong> bucket must exist in Supabase Storage.</p>
            <p>2. RLS policies must allow authenticated writes to <code>migrated/</code> prefix.</p>
            <p>3. This migration is safe to re-run — it only processes rows still containing base64 data.</p>
            <p>4. Delete this admin page and its route after confirming migration success.</p>
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
              {running ? 'Migration in progress…' : done ? '✅ Run Again' : '🚀 Start Migration'}
            </Button>

            {/* Progress bar */}
            {(running || done) && stats.total > 0 && (
              <div className="space-y-1">
                <div className="flex justify-between text-sm text-muted-foreground">
                  <span>Progress</span>
                  <span>{stats.processed + stats.failed} / {stats.total} ({pct}%)</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2.5">
                  <div
                    className={`h-2.5 rounded-full transition-all ${stats.failed > 0 ? 'bg-amber-500' : 'bg-primary'}`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="flex gap-4 text-xs text-muted-foreground">
                  <span className="text-green-600">✅ {stats.processed} ok</span>
                  {stats.failed > 0 && <span className="text-red-600">❌ {stats.failed} failed</span>}
                  <span>📦 {stats.total} total</span>
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
              <div className="bg-gray-900 text-gray-100 rounded-lg p-4 h-72 overflow-y-auto font-mono text-xs space-y-0.5">
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
                All {stats.processed} flashcard image(s) have been moved to Storage.
                You can now delete this admin page (<code>src/pages/admin/MigrateFlashcards.jsx</code>)
                and remove its route from <code>App.jsx</code>.
              </p>
            </CardContent>
          </Card>
        )}

      </div>
    </div>
  );
}
