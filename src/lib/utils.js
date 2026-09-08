import { clsx } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

// ── RevisOp custom utility scales ──────────────────────────────────────────────
// tailwind-merge's default config doesn't know these project-specific scales, so
// conflicting classes weren't always de-duplicated and CSS source order decided
// the winner instead of "last class wins":
//   • rounded-rec / rounded-obj   two-tier radius (4px / 14px) — NOT merged at all
//   • shadow-rv / shadow-rv-bar   elevation pair
//   • text/bg/border-rv-*         the --rv-* colour scale (the colour position is
//                                 handled by tw-merge's permissive fallback today,
//                                 registered here so it stays reliable across
//                                 tailwind-merge upgrades)
// Registering them means cn() resolves an appended override everywhere — e.g.
// <Num className="text-rv-danger"> beats the atom's baked text-rv-ink-900, and a
// <Card className="rounded-lg"> override actually wins over rounded-obj.
// Sprint 7.0 (7.0-D).
const RV_COLORS = [
  "rv-bg-0", "rv-bg-1", "rv-bg-2", "rv-border", "rv-border-strong",
  "rv-ink-900", "rv-ink-600", "rv-ink-400",
  "rv-navy", "rv-navy-400", "rv-navy-100", "rv-navy-50",
  "rv-amber", "rv-amber-ink", "rv-amber-50", "rv-amber-edge",
  "rv-green", "rv-green-50", "rv-slate", "rv-slate-50", "rv-danger",
];

const twMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      rounded: [{ rounded: ["rec", "obj"] }],
      shadow: [{ shadow: ["rv", "rv-bar"] }],
      "text-color": [{ text: RV_COLORS }],
      "bg-color": [{ bg: RV_COLORS }],
      "border-color": [{ border: RV_COLORS }],
    },
  },
});

export function cn(...inputs) {
  return twMerge(clsx(inputs));
}
