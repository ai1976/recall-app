import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import ContentPreviewWall from '@/components/ui/ContentPreviewWall';
import { publicRows, courseRow } from '@/lib/courseOptions.fixtures';

const submitAccessRequest = vi.fn();
vi.mock('@/lib/dueSet', () => ({ submitAccessRequest: (...a) => submitAccessRequest(...a) }));
let authState = { user: null, loading: false };
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => authState }));
vi.mock('@/hooks/use-toast', () => ({ useToast: () => ({ toast: vi.fn() }) }));

const rpc = vi.fn();
let savedCourse = null;
const profileRead = vi.fn();
vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...a) => rpc(...a),
    from: () => ({ select: () => ({ eq: () => ({ single: () => { profileRead(); return Promise.resolve({ data: { course_level: savedCourse }, error: null }); } }) }) }),
  },
}));

beforeAll(() => {
  // Radix Select needs these in jsdom.
  window.HTMLElement.prototype.hasPointerCapture = () => false;
  window.HTMLElement.prototype.releasePointerCapture = () => {};
  window.HTMLElement.prototype.scrollIntoView = () => {};
});

beforeEach(() => {
  submitAccessRequest.mockReset();
  submitAccessRequest.mockResolvedValue({ error: null });
  rpc.mockReset();
  rpc.mockResolvedValue({ data: publicRows(), error: null });
  authState = { user: null, loading: false };
  savedCourse = null;
  profileRead.mockReset();
});

function fillBasics() {
  fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Asha' } });
  fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'asha@example.com' } });
  fireEvent.change(screen.getByLabelText('WhatsApp Number'), { target: { value: '+919876543210' } });
}

async function openCourseList() {
  const combobox = screen.getByRole('combobox');
  await waitFor(() => expect(combobox).not.toBeDisabled());
  fireEvent.keyDown(combobox, { key: 'Enter' });
}

async function chooseOther() {
  await openCourseList();
  fireEvent.click(screen.getByRole('option', { name: 'Other, type your own' }));
}

describe('ContentPreviewWall course field (T-002 F0)', () => {
  it('offers a real text input instead of the literal Other, and sends the trimmed typed course', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    await chooseOther();
    const button = screen.getByRole('button', { name: /Notify me/ });
    expect(button).toBeDisabled();
    fireEvent.change(screen.getByLabelText('Your course'), { target: { value: '  CFA Level 1  ' } });
    expect(button).not.toBeDisabled();
    fireEvent.click(button);
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('CFA Level 1');
  });

  it('blocks a whitespace-only, over-long or control-character course with a visible message and no request', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    await chooseOther();
    const input = screen.getByLabelText('Your course');
    const button = screen.getByRole('button', { name: /Notify me/ });
    const cases = [
      ['   ', /enter your course name/],
      ['x'.repeat(121), /too long/],
      ['ab\tc', /control characters/],
      ['CFA\t', /control characters/],
    ];
    for (const [value, message] of cases) {
      fireEvent.change(input, { target: { value } });
      expect(button).toBeDisabled();
      expect(screen.getByRole('alert').textContent).toMatch(message);
    }
    fireEvent.submit(button.closest('form'));
    expect(submitAccessRequest).not.toHaveBeenCalled();
  });

  it('accepts the word Other as a typed course (no reserved word) and never sends the dropdown value', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    await chooseOther();
    fireEvent.change(screen.getByLabelText('Your course'), { target: { value: 'Other' } });
    fireEvent.click(screen.getByRole('button', { name: /Notify me/ }));
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('Other');
  });

  it('still sends a listed course unchanged', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    await openCourseList();
    fireEvent.click(screen.getByRole('option', { name: 'CA Final' }));
    fireEvent.click(screen.getByRole('button', { name: /Notify me/ }));
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('CA Final');
  });

  it('sends a typed course that is already in the list as that listed course', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    await chooseOther();
    fireEvent.change(screen.getByLabelText('Your course'), { target: { value: '  ca   final ' } });
    fireEvent.click(screen.getByRole('button', { name: /Notify me/ }));
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('CA Final');
  });
});

describe('ContentPreviewWall course list (T-002 F1)', () => {
  it('uses the public list for a visitor and the access list for a signed-in student, never before the session state is known', async () => {
    authState = { user: null, loading: true };
    const { rerender } = render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    expect(rpc).not.toHaveBeenCalled();
    authState = { user: null, loading: false };
    rerender(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('get_course_options_public'));

    rpc.mockClear();
    authState = { user: { id: 'u1' }, loading: false };
    rerender(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('get_course_options', { p_surface: 'access' }));
  });

  it('preselects the signed-in student\'s current course, including one that is no longer offered', async () => {
    authState = { user: { id: 'u1' }, loading: false };
    const rows = publicRows().map((row) => (row.label === 'CA Foundation' ? { ...row, is_active: false, is_current: true } : row));
    rpc.mockResolvedValue({ data: rows, error: null });
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    const combobox = screen.getByRole('combobox');
    await waitFor(() => expect(combobox.textContent).toMatch(/CA Foundation \(no longer offered\)/));
    fireEvent.click(screen.getByRole('button', { name: /Notify me/ }));
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('CA Foundation');
  });

  it('reads nothing about the student before the session state is known', async () => {
    authState = { user: { id: 'u1' }, loading: true };
    const { rerender } = render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(profileRead).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
    authState = { user: { id: 'u1' }, loading: false };
    rerender(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    await waitFor(() => expect(profileRead).toHaveBeenCalledTimes(1));
  });

  it('leaves the field empty and says why when the saved course is too long', async () => {
    authState = { user: { id: 'u1' }, loading: false };
    savedCourse = 'z'.repeat(121);
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    await waitFor(() => expect(screen.getByRole('status').textContent).toMatch(/too long to use as a name/));
    expect(screen.getByRole('button', { name: /Notify me/ })).toBeDisabled();
  });

  it('shows a neutral state and sends nothing when the list breaks the contract', async () => {
    rpc.mockResolvedValue({ data: [courseRow({ kind: 'platform', label: 'CA Final', discipline_id: 'd' })], error: null });
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/could not be loaded/i));
    expect(screen.getByRole('combobox')).toBeDisabled();
    fireEvent.submit(screen.getByRole('button', { name: /Notify me/ }).closest('form'));
    expect(submitAccessRequest).not.toHaveBeenCalled();
  });
});
