// Behaviour tests for the heatmap (T-001 brief C v6, C-7.4 and C-7.5 item 6): every day is a focusable button with an accessible name, hover and focus show a
// card, tap or Enter pins it, and it closes on Escape, on a second tap, on focus loss and on a tap outside; reduced motion is respected.
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn() } }));

import { supabase } from '@/lib/supabase';
import StudyHeatmap from '@/components/progress/StudyHeatmap';

const ROWS = [
  { review_date: '2026-10-07', review_count: 5, in_app_seconds: 600, offline_seconds: 1800, study_seconds: 2400, other_seconds: 0 },
  { review_date: '2026-10-06', review_count: 0, in_app_seconds: 0, offline_seconds: 5400, study_seconds: 5400, other_seconds: 0 },
  { review_date: '2026-10-05', review_count: 3, in_app_seconds: 300, offline_seconds: 0, study_seconds: 300, other_seconds: 0 },
];

async function setup(rows = ROWS) {
  supabase.rpc.mockResolvedValue({ data: rows, error: null });
  const view = render(<StudyHeatmap userId="u1" />);
  await waitFor(() => expect(document.querySelector('[data-date]')).not.toBeNull());
  return view;
}
const cell = (date) => document.querySelector(`[data-date="${date}"]`);

beforeEach(() => {
  vi.useFakeTimers({ shouldAdvanceTime: true, toFake: ['Date'] });
  vi.setSystemTime(new Date(2026, 9, 7, 15, 0, 0));
  supabase.rpc.mockReset();
});
afterEach(() => { vi.useRealTimers(); });

describe('data and structure', () => {
  it('reads the split RPC for 90 days and draws 91 focusable day buttons', async () => {
    await setup();
    expect(supabase.rpc).toHaveBeenCalledWith('get_study_heatmap_split', { p_user_id: 'u1', p_days: 90 });
    expect(document.querySelectorAll('button[data-date]')).toHaveLength(91);
  });

  it('gives every day an accessible name with date, in-app, offline, total and reviews, and removes the native title', async () => {
    await setup();
    const label = cell('2026-10-07').getAttribute('aria-label');
    expect(label).toMatch(/in-app 10m, offline 30m, total study time 40m, 5 reviews/);
    expect(cell('2026-10-07').hasAttribute('title')).toBe(false);
    expect(cell('2026-10-01').getAttribute('aria-label')).toMatch(/no activity/);
    expect(screen.getByRole('group', { name: /study activity by day/i })).toBeInTheDocument();
  });

  it('shows the summary line and an error message when the RPC fails', async () => {
    await setup();
    expect(screen.getByText(/3 active days/)).toBeInTheDocument();
    supabase.rpc.mockResolvedValue({ data: null, error: { message: 'boom' } });
    document.body.innerHTML = '';
    render(<StudyHeatmap userId="u2" />);
    expect(await screen.findByText(/Could not load heatmap/)).toBeInTheDocument();
  });
});

describe('hover and focus show a card; tap or Enter pins it', () => {
  it('hover shows the card with date, in-app, offline, total and reviews, and leaving hides it', async () => {
    await setup();
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
    fireEvent.mouseEnter(cell('2026-10-07'));
    const card = screen.getByTestId('heatmap-card');
    expect(card).toHaveTextContent('In-app');
    expect(card).toHaveTextContent('10m');
    expect(card).toHaveTextContent('Offline');
    expect(card).toHaveTextContent('30m');
    expect(card).toHaveTextContent('Total');
    expect(card).toHaveTextContent('40m');
    expect(card).toHaveTextContent('Reviews');
    fireEvent.mouseLeave(cell('2026-10-07'));
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
  });

  it('keyboard focus shows the card and blurring out of the heatmap hides it', async () => {
    await setup();
    act(() => cell('2026-10-07').focus());
    expect(screen.getByTestId('heatmap-card')).toBeInTheDocument();
    fireEvent.blur(cell('2026-10-07'), { relatedTarget: null });
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
  });

  it('a tap pins the card, a second tap on the same day closes it even while hovered and focused', async () => {
    await setup();
    const c = cell('2026-10-06');
    fireEvent.mouseEnter(c);
    act(() => c.focus());
    fireEvent.click(c);
    expect(c.getAttribute('aria-pressed')).toBe('true');
    expect(screen.getByTestId('heatmap-card')).toHaveTextContent('(pinned)');
    fireEvent.mouseLeave(c);
    expect(screen.getByTestId('heatmap-card')).toBeInTheDocument(); // still pinned
    fireEvent.mouseEnter(c);
    fireEvent.click(c);
    expect(c.getAttribute('aria-pressed')).toBe('false');
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
  });

  it('tapping another day moves the pin; the card for a day with no activity says so', async () => {
    await setup();
    fireEvent.click(cell('2026-10-07'));
    fireEvent.click(cell('2026-10-01'));
    expect(cell('2026-10-07').getAttribute('aria-pressed')).toBe('false');
    expect(screen.getByTestId('heatmap-card')).toHaveTextContent('No activity');
  });
});

describe('closing a pinned card', () => {
  it('Escape closes it', async () => {
    await setup();
    const c = cell('2026-10-07');
    act(() => c.focus());
    fireEvent.click(c);
    expect(screen.getByTestId('heatmap-card')).toBeInTheDocument();
    fireEvent.keyDown(c, { key: 'Escape' });
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
    expect(c.getAttribute('aria-pressed')).toBe('false');
  });

  it('focus leaving the heatmap closes it, but moving focus to another day inside the heatmap does not', async () => {
    await setup();
    const a = cell('2026-10-07');
    const b = cell('2026-10-06');
    act(() => a.focus());
    fireEvent.click(a);
    fireEvent.blur(a, { relatedTarget: b });
    expect(a.getAttribute('aria-pressed')).toBe('true');
    fireEvent.blur(a, { relatedTarget: document.body });
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
  });

  it('a pointer press outside the heatmap closes it (a touch tap does not always move focus)', async () => {
    await setup();
    fireEvent.click(cell('2026-10-07'));
    expect(screen.getByTestId('heatmap-card')).toBeInTheDocument();
    fireEvent.pointerDown(document.body);
    expect(screen.queryByTestId('heatmap-card')).toBeNull();
  });

  it('a pointer press inside the heatmap does not close it', async () => {
    await setup();
    fireEvent.click(cell('2026-10-07'));
    fireEvent.pointerDown(cell('2026-10-06'));
    expect(screen.getByTestId('heatmap-card')).toBeInTheDocument();
  });
});

describe('keyboard navigation', () => {
  it('has exactly one tab stop, on today, and arrow keys move by day and by week', async () => {
    await setup();
    const stops = [...document.querySelectorAll('button[data-date]')].filter((b) => b.tabIndex === 0);
    expect(stops).toHaveLength(1);
    expect(stops[0].dataset.date).toBe('2026-10-07');
    const today = cell('2026-10-07');
    act(() => today.focus());
    fireEvent.keyDown(today, { key: 'ArrowUp' });
    expect(document.activeElement.dataset.date).toBe('2026-10-06');
    fireEvent.keyDown(document.activeElement, { key: 'ArrowLeft' });
    expect(document.activeElement.dataset.date).toBe('2026-09-29');
    fireEvent.keyDown(document.activeElement, { key: 'ArrowDown' });
    expect(document.activeElement.dataset.date).toBe('2026-09-30');
    fireEvent.keyDown(document.activeElement, { key: 'ArrowRight' });
    expect(document.activeElement.dataset.date).toBe('2026-10-07');
    fireEvent.keyDown(document.activeElement, { key: 'ArrowRight' }); // cannot go past today
    expect(document.activeElement.dataset.date).toBe('2026-10-07');
    fireEvent.keyDown(document.activeElement, { key: 'Home' });
    expect(document.activeElement.dataset.date).toBe('2026-07-09');
    fireEvent.keyDown(document.activeElement, { key: 'End' });
    expect(document.activeElement.dataset.date).toBe('2026-10-07');
  });

  it('after moving, the day that has focus is the one tab stop', async () => {
    await setup();
    const today = cell('2026-10-07');
    act(() => today.focus());
    fireEvent.keyDown(today, { key: 'ArrowUp' });
    const stops = [...document.querySelectorAll('button[data-date]')].filter((b) => b.tabIndex === 0);
    expect(stops.map((b) => b.dataset.date)).toEqual(['2026-10-06']);
  });
});

describe('motion and layout', () => {
  it('only animates under motion-safe, so reduced motion is respected', async () => {
    await setup();
    fireEvent.mouseEnter(cell('2026-10-07'));
    const cls = screen.getByTestId('heatmap-card').className;
    expect(cls).toMatch(/motion-safe:transition-opacity/);
    expect(cls.split(/\s+/).filter((c) => /^(transition|duration|animate)/.test(c))).toEqual([]);
  });

  it('draws future days of the current week as inert spacers, not buttons', async () => {
    await setup();
    expect(cell('2026-10-08')).toBeNull();
    expect(document.querySelectorAll('button[data-date]')).toHaveLength(91);
  });
});
