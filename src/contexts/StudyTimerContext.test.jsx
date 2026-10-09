import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { StudyTimerProvider, useStudyTimer } from '@/contexts/StudyTimerContext';

const insert = vi.fn();
vi.mock('@/lib/supabase', () => ({ supabase: { from: (table) => ({ insert: (row) => insert(table, row) }) } }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u1' } }) }));

const PENDING = { startedAt: Date.parse('2026-10-09T08:00:00Z'), durationSeconds: 3600, endedAt: '2026-10-09T09:00:00.000Z', sessionDate: '2026-10-09' };

beforeEach(() => {
  window.localStorage.clear();
  insert.mockReset();
  insert.mockResolvedValue({ error: null });
});

function mount() {
  return renderHook(() => useStudyTimer(), { wrapper: StudyTimerProvider });
}

describe('StudyTimerContext.confirmCategory (T-002 F1)', () => {
  it('stores the classification columns together with the category, for a platform, a custom and a General log', async () => {
    window.localStorage.setItem('revisop_manual_timer_pending_log', JSON.stringify(PENDING));
    const { result } = mount();
    expect(result.current.pendingLog).toBeTruthy();
    await act(async () => { await result.current.confirmCategory('reading', { classification: 'platform', discipline_id: 'd1', subject_id: 's1' }); });
    expect(insert).toHaveBeenCalledWith('study_sessions', {
      user_id: 'u1', started_at: new Date(PENDING.startedAt).toISOString(), ended_at: PENDING.endedAt, duration_seconds: 3600, session_date: '2026-10-09',
      source: 'manual', category: 'reading', classification: 'platform', discipline_id: 'd1', subject_id: 's1',
    });
    expect(window.localStorage.getItem('revisop_manual_timer_pending_log')).toBeNull();
  });

  it('stores a restored pending log classified: a log left unconfirmed before the upgrade passes through the same call', async () => {
    window.localStorage.setItem('revisop_manual_timer_pending_log', JSON.stringify(PENDING));
    const { result } = mount();
    await act(async () => { await result.current.confirmCategory('mock_test', { classification: 'custom', custom_course_label: 'ACCA', custom_subject_label: 'Tax' }); });
    const row = insert.mock.calls[0][1];
    expect(row.source).toBe('manual');
    expect(row.classification).toBe('custom');
    expect(row.custom_course_label).toBe('ACCA');
    expect(row.custom_subject_label).toBe('Tax');
  });

  it('writes nothing and keeps the pending log when the classification is missing or malformed (never a manual log without one)', async () => {
    window.localStorage.setItem('revisop_manual_timer_pending_log', JSON.stringify(PENDING));
    const { result } = mount();
    for (const bad of [undefined, null, {}, { classification: 'platform' }, { classification: 'custom', custom_course_label: 'A', discipline_id: 'd1' }]) {
      let outcome;
      await act(async () => { outcome = await result.current.confirmCategory('reading', bad); });
      expect(outcome).toEqual({ outcome: 'invalid' });
    }
    expect(insert).not.toHaveBeenCalled();
    expect(window.localStorage.getItem('revisop_manual_timer_pending_log')).not.toBeNull();
  });

  it('keeps the pending log and throws when the database refuses the row', async () => {
    window.localStorage.setItem('revisop_manual_timer_pending_log', JSON.stringify(PENDING));
    insert.mockResolvedValue({ error: { code: '23514' } });
    const { result } = mount();
    await expect(act(async () => { await result.current.confirmCategory('reading', { classification: 'general' }); })).rejects.toMatchObject({ code: '23514' });
    expect(window.localStorage.getItem('revisop_manual_timer_pending_log')).not.toBeNull();
  });

  it('still refuses an unknown category', async () => {
    window.localStorage.setItem('revisop_manual_timer_pending_log', JSON.stringify(PENDING));
    const { result } = mount();
    let outcome;
    await act(async () => { outcome = await result.current.confirmCategory('dancing', { classification: 'general' }); });
    expect(outcome).toEqual({ outcome: 'noop' });
    expect(insert).not.toHaveBeenCalled();
  });
});
