import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import ContentPreviewWall from '@/components/ui/ContentPreviewWall';

const submitAccessRequest = vi.fn();
vi.mock('@/lib/dueSet', () => ({ submitAccessRequest: (...a) => submitAccessRequest(...a) }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: null }) }));
vi.mock('@/hooks/use-toast', () => ({ useToast: () => ({ toast: vi.fn() }) }));

beforeAll(() => {
  // Radix Select needs these in jsdom.
  window.HTMLElement.prototype.hasPointerCapture = () => false;
  window.HTMLElement.prototype.releasePointerCapture = () => {};
  window.HTMLElement.prototype.scrollIntoView = () => {};
});

beforeEach(() => {
  submitAccessRequest.mockReset();
  submitAccessRequest.mockResolvedValue({ error: null });
});

function fillBasics() {
  fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Asha' } });
  fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'asha@example.com' } });
  fireEvent.change(screen.getByLabelText('WhatsApp Number'), { target: { value: '+919876543210' } });
}

function chooseOther() {
  fireEvent.keyDown(screen.getByRole('combobox'), { key: 'Enter' });
  fireEvent.click(screen.getByRole('option', { name: 'Other (type your course)' }));
}

describe('ContentPreviewWall course field (T-002 F0)', () => {
  it('offers a real text input instead of the literal Other, and sends the trimmed typed course', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    chooseOther();
    const button = screen.getByRole('button', { name: /Notify me/ });
    expect(button).toBeDisabled();
    fireEvent.change(screen.getByLabelText('Your course'), { target: { value: '  CFA Level 1  ' } });
    expect(button).not.toBeDisabled();
    fireEvent.click(button);
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('CFA Level 1');
  });

  it('blocks a whitespace-only, over-long or control-character course with a visible message and no request', () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    chooseOther();
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
    chooseOther();
    fireEvent.change(screen.getByLabelText('Your course'), { target: { value: 'Other' } });
    fireEvent.click(screen.getByRole('button', { name: /Notify me/ }));
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('Other');
  });

  it('still sends a listed course unchanged', async () => {
    render(<ContentPreviewWall contentId="c1" contentType="note" contentName="n" />);
    fillBasics();
    fireEvent.keyDown(screen.getByRole('combobox'), { key: 'Enter' });
    fireEvent.click(screen.getByRole('option', { name: 'CA Final' }));
    fireEvent.click(screen.getByRole('button', { name: /Notify me/ }));
    await waitFor(() => expect(submitAccessRequest).toHaveBeenCalledTimes(1));
    expect(submitAccessRequest.mock.calls[0][0].p_course).toBe('CA Final');
  });
});
