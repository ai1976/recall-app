// The Progress forecast tile (T-001 brief C v6): an unknown value is a dash in the neutral tone, never the green "calm / nothing due" tone.
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import ForecastCard from '@/components/progress/ForecastCard';

describe('ForecastCard', () => {
  it('shows the number in the tone it was given when the value is known, including a real zero in the calm tone', () => {
    const { container } = render(<ForecastCard label="Due Today" value={0} tone="calm" />);
    expect(screen.getByText('0')).toBeInTheDocument();
    expect(container.firstChild.getAttribute('data-tone')).toBe('calm');
    expect(container.firstChild.className).toMatch(/bg-rv-green-50/);
  });

  it('shows a dash and the quiet tone when the value is unknown, whatever tone the page asked for', () => {
    for (const tone of ['calm', 'amber', 'danger']) {
      for (const value of [null, undefined]) {
        const { container, unmount } = render(<ForecastCard label="Due Today" value={value} tone={tone} />);
        expect(screen.getByText('\u2014')).toBeInTheDocument();
        expect(container.firstChild.getAttribute('data-tone')).toBe('quiet');
        expect(container.firstChild.className).not.toMatch(/bg-rv-green-50|bg-rv-amber-50|border-rv-danger/);
        unmount();
      }
    }
  });

  it('keeps the amber and danger tones for known values', () => {
    const { container } = render(<ForecastCard label="Due Today" value={30} tone="danger" />);
    expect(container.firstChild.getAttribute('data-tone')).toBe('danger');
  });
});
