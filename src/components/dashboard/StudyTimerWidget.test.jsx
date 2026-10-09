import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import StudyTimerWidget from '@/components/dashboard/StudyTimerWidget';
import { pickerRows, subjectRows, customSubjectRows } from '@/lib/courseOptions.fixtures';

const confirmCategory = vi.fn();
let timerState;
vi.mock('@/contexts/StudyTimerContext', () => ({ useStudyTimer: () => timerState }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u1' }, loading: false }) }));
const toast = vi.fn();
vi.mock('@/hooks/use-toast', () => ({ useToast: () => ({ toast: (...a) => toast(...a) }) }));

const rpc = vi.fn();
vi.mock('@/lib/supabase', () => ({ supabase: { rpc: (...a) => rpc(...a) } }));

function serve({ rows = pickerRows('CA Final', ['CFA Level 1']), subjects = subjectRows(['Audit', 'Tax']), customSubjects = customSubjectRows(['Ethics']), subjectsFail = false } = {}) {
  rpc.mockImplementation((name, params) => {
    if (name === 'get_course_options') return Promise.resolve({ data: rows, error: null });
    if (name === 'get_picker_subjects') {
      if (subjectsFail) return Promise.resolve({ data: null, error: { message: 'down' } });
      return Promise.resolve({ data: params && params.p_course_key ? customSubjects : subjects, error: null });
    }
    return Promise.resolve({ data: null, error: { message: 'unexpected ' + name } });
  });
}

function pending() {
  return { startedAt: Date.now() - 3_600_000, durationSeconds: 3600, endedAt: new Date().toISOString(), sessionDate: '2026-10-09' };
}

beforeEach(() => {
  window.localStorage.clear();
  confirmCategory.mockReset();
  confirmCategory.mockResolvedValue({ outcome: 'logged', durationSeconds: 3600 });
  toast.mockReset();
  rpc.mockReset();
  serve();
  timerState = {
    isRunning: false, startedAt: null, recoveryPrompt: null, pendingLog: pending(),
    start: vi.fn(), stop: vi.fn(), stopAndLog: vi.fn(), discard: vi.fn(), confirmCategory,
  };
});

async function ready() {
  render(<StudyTimerWidget />);
  await waitFor(() => expect(screen.getByText(/CA Final/)).toBeTruthy());
  await waitFor(() => expect(rpc).toHaveBeenCalledWith('get_picker_subjects', expect.anything()));
  await waitFor(() => expect(screen.getByText(/Skip/)).toBeTruthy());
}

describe('Study log picker (T-002 F1)', () => {
  it('shows the current course already chosen and the subject skipped, and the picker for a restored pending log', async () => {
    await ready();
    expect(rpc).toHaveBeenCalledWith('get_course_options', { p_surface: 'picker' });
    expect(rpc).toHaveBeenCalledWith('get_picker_subjects', { p_discipline_id: 'd-0' });
    expect(screen.getByText(/What were you studying/)).toBeTruthy();
  });

  it('saves a platform log with the discipline and the category, and remembers the subject on this device', async () => {
    await ready();
    fireEvent.click(screen.getByText(/Skip/).closest('button'));
    fireEvent.click(await screen.findByRole('button', { name: 'Tax' }));
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(confirmCategory).toHaveBeenCalledTimes(1));
    expect(confirmCategory).toHaveBeenCalledWith('reading', { classification: 'platform', discipline_id: 'd-0', subject_id: 's-1' });
    expect(window.localStorage.getItem('revisop_last_subject_d:d-0')).toBe('s-1');
  });

  it('keeps Save disabled until a category is chosen', async () => {
    await ready();
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled();
    fireEvent.click(screen.getByRole('button', { name: 'Mock Test (timed)' }));
    expect(screen.getByRole('button', { name: 'Save' })).not.toBeDisabled();
  });

  it('saves General with no course columns', async () => {
    await ready();
    fireEvent.click(screen.getByText(/CA Final/).closest('button'));
    fireEvent.click(await screen.findByRole('button', { name: 'General' }));
    fireEvent.click(screen.getByRole('button', { name: 'Paper Solving' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(confirmCategory).toHaveBeenCalledWith('paper_solving', { classification: 'general' }));
  });

  it('saves an earlier custom course as text and a typed course trimmed', async () => {
    await ready();
    fireEvent.click(screen.getByText(/CA Final/).closest('button'));
    fireEvent.click(await screen.findByRole('button', { name: 'CFA Level 1' }));
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Save' })).not.toBeDisabled());
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(confirmCategory).toHaveBeenCalledWith('reading', { classification: 'custom', custom_course_label: 'CFA Level 1' }));
  });

  it('lets the student type a course and a subject, and blocks invalid text with a message', async () => {
    await ready();
    fireEvent.click(screen.getByText(/CA Final/).closest('button'));
    fireEvent.click(await screen.findByRole('button', { name: 'Other...' }));
    const course = await screen.findByLabelText('Your course');
    fireEvent.change(course, { target: { value: 'x'.repeat(121) } });
    expect(screen.getByRole('alert').textContent).toMatch(/too long/);
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(toast).toHaveBeenCalled());
    expect(confirmCategory).not.toHaveBeenCalled();
    fireEvent.change(course, { target: { value: '  ACCA  ' } });
    fireEvent.change(screen.getByLabelText('Subject'), { target: { value: ' Taxation ' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(confirmCategory).toHaveBeenCalledWith('reading', { classification: 'custom', custom_course_label: 'ACCA', custom_subject_label: 'Taxation' }));
  });

  it('keeps the session and the choices when saving fails, and explains a refused name', async () => {
    confirmCategory.mockRejectedValue({ code: '23514' });
    await ready();
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(toast).toHaveBeenCalled());
    expect(toast.mock.calls[0][0].description).toMatch(/cannot be saved as typed/);
    expect(screen.getByText(/What were you studying/)).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Save' })).not.toBeDisabled();
  });

  it('cannot save while the subject list of a listed course is unavailable (a failed subject call is a contract failure)', async () => {
    serve({ subjectsFail: true });
    render(<StudyTimerWidget />);
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/subject list could not be loaded/));
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled();
    expect(confirmCategory).not.toHaveBeenCalled();
  });

  it('can still save General, which has no subject list, and a typed course, which has none either', async () => {
    serve({ subjectsFail: true });
    render(<StudyTimerWidget />);
    await waitFor(() => expect(screen.getByRole('alert')).toBeTruthy());
    fireEvent.click(screen.getByText(/CA Final/).closest('button'));
    fireEvent.click(await screen.findByRole('button', { name: 'General' }));
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(confirmCategory).toHaveBeenCalledWith('reading', { classification: 'general' }));
  });

  it('offers no choice and cannot save when the course list breaks the contract', async () => {
    serve({ rows: pickerRows('CA Final').filter((row) => row.kind !== 'general').map((row, i) => ({ ...row, position: i + 1 })) });
    render(<StudyTimerWidget />);
    await waitFor(() => expect(screen.getByText(/course list could not be loaded/i)).toBeTruthy());
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled();
  });

  it('starts without a course when the student has no current course and will not save until one is chosen', async () => {
    serve({ rows: pickerRows(null, ['CFA Level 1']) });
    render(<StudyTimerWidget />);
    await waitFor(() => expect(screen.getByText('Choose a course')).toBeTruthy());
    fireEvent.click(screen.getByRole('button', { name: 'Reading' }));
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled();
    expect(rpc).not.toHaveBeenCalledWith('get_picker_subjects', expect.anything());
  });
});
