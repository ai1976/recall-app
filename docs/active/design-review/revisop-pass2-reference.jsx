import React, { useState, useEffect, useRef } from "react";
import {
  Check, X, ChevronDown, ChevronUp, Home, Layers, BarChart3, Users,
  Search, ShieldCheck, ArrowLeft, Sun, Moon, Smartphone, Monitor,
  GraduationCap, Building2, Trash2
} from "lucide-react";

/* ─────────────────────────────────────────────────────────────
   TOKENS
   ───────────────────────────────────────────────────────────── */

const SANS = "'IBM Plex Sans', ui-sans-serif, system-ui, sans-serif";
const MONO = "'IBM Plex Mono', ui-monospace, monospace";
const READ = "'Literata', Georgia, 'Times New Roman', serif";

const LIGHT = {
  dark: false,
  bg0: "#f9f9fb", bg1: "#ffffff", bg2: "#f0f0f8",
  border: "#e2e8f0", borderStrong: "#cbd5e1",
  ink900: "#0a0e1a", ink600: "#374151", ink400: "#6b7280",
  navy: "#1e1b4b", navyText: "#1e1b4b", navy400: "#4a4590",
  navy100: "#e0e0f0", navy50: "#f0f0f8",
  amber: "#f59e0b", amberInk: "#0a0e1a", amber50: "#fffbeb", amberEdge: "#fcd34d",
  green: "#16a34a", green50: "#f0fdf4",
  slate: "#475569", slate50: "#f1f5f9",
  danger: "#b91c1c",
  shadow: "0 2px 8px rgba(30,27,75,.10)",
  shadowBar: "0 -2px 10px rgba(30,27,75,.07)"
};

const DARK = {
  dark: true,
  bg0: "#0d0f24", bg1: "#171a35", bg2: "#1f2340",
  border: "#2e3355", borderStrong: "#3c4270",
  ink900: "#eef0f8", ink600: "#c3c8db", ink400: "#9aa1b8",
  navy: "#a5b4fc", navyText: "#a5b4fc", navy400: "#8b96e8",
  navy100: "#2e3355", navy50: "#1f2340",
  amber: "#fbbf24", amberInk: "#0d0f24", amber50: "#2a2210", amberEdge: "#7c5a0d",
  green: "#22c55e", green50: "#10281c",
  slate: "#94a3b8", slate50: "#232743",
  danger: "#ef4444",
  shadow: "0 2px 10px rgba(0,0,0,.45)",
  shadowBar: "0 -2px 12px rgba(0,0,0,.4)"
};

const R_REC = 4;   // records
const R_OBJ = 14;  // study objects

/* ─────────────────────────────────────────────────────────────
   CONTENT
   ───────────────────────────────────────────────────────────── */

const BUCKETS = ["Today", "1d", "3d", "6d", "2w", "1mo", "3mo", "6mo+"];

const TODAY_LOAD = [28, 12, 18, 9, 14, 7, 4, 2];
const COHORT_LOAD = [340, 214, 486, 262, 388, 176, 88, 41];

const DUE_DECKS = [
  { name: "Accounting Standards · AS 10–16", due: 9, kind: "Questions", verified: true, last: "2d ago" },
  { name: "Cost Accounting · Overheads", due: 7, kind: "Questions", verified: true, last: "3d ago" },
  { name: "Corporate Laws · Ch. 5–8", due: 6, kind: "Case studies", verified: true, last: "6d ago" },
  { name: "Direct Tax · Capital gains", due: 4, kind: "Flashcards", verified: false, last: "1d ago" },
  { name: "GST · Input tax credit", due: 2, kind: "Concept cards", verified: true, last: "9d ago" }
];

const ITEMS = [
  {
    id: "q1",
    type: "single",
    deck: "Accounting Standards",
    topic: "AS 10 · Property, plant & equipment",
    chip: "6d",
    pos: [7, 24],
    verified: "CA Meera Raghavan",
    stem: "A machine is bought for ₹8,00,000. Which of these costs must NOT be capitalised as part of its cost under AS 10?",
    long: false,
    options: [
      "Site preparation and installation charges",
      "Initial delivery and handling costs",
      "Staff training on how to operate the machine",
      "Professional fees of the erection engineer"
    ],
    correct: 2,
    why: "Training is a cost of using the asset, not of bringing it to working condition. It is expensed as incurred.",
    grades: [
      { label: "Hard", iv: "1d", bucket: 1 },
      { label: "Medium", iv: "4d", bucket: 3 },
      { label: "Easy", iv: "9d", bucket: 4 }
    ]
  },
  {
    id: "q2",
    type: "match",
    deck: "Cost Accounting",
    topic: "Overhead absorption",
    chip: "3d",
    pos: [8, 24],
    verified: "CMA Arjun Pillai",
    stem: "Match each absorption base with the situation it suits best.",
    left: [
      "Machine hour rate",
      "Direct labour hour rate",
      "Rate per unit of output",
      "Percentage of prime cost"
    ],
    right: [
      { k: "A", v: "Highly automated shop floor" },
      { k: "B", v: "Labour-intensive assembly work" },
      { k: "C", v: "One uniform product, one process" },
      { k: "D", v: "Small job shop, mixed cost profile" }
    ],
    correct: { 0: "A", 1: "B", 2: "C", 3: "D" },
    why: "The base should track whatever actually drives the overhead — machines, people, units, or a rough blend when nothing dominates.",
    grades: [
      { label: "Hard", iv: "1d", bucket: 1 },
      { label: "Medium", iv: "3d", bucket: 2 },
      { label: "Easy", iv: "6d", bucket: 3 }
    ]
  },
  {
    id: "q3",
    type: "case",
    deck: "Corporate & Other Laws",
    topic: "Sec 188 · Related party transactions",
    chip: "2w",
    pos: [9, 24],
    verified: "CS Devika Nair",
    caseTitle: "Case 4 · Meridian Auto Components",
    caseNo: [2, 3],
    passage:
      "Meridian Auto Components Pvt Ltd has a paid-up capital of ₹6 crore. At its board meeting on 14 May, the directors took up a proposed three-year haulage contract with Sunview Logistics LLP, in which Meridian's managing director's brother is a partner. Sunview quoted ₹92 lakh a year. Two independent quotations on record were ₹94 lakh and ₹97 lakh for the same scope. Meridian has outsourced haulage every year since incorporation, and the contract terms match its existing vendor agreements in all material respects.",
    stem: "What approval does the Sunview contract require?",
    long: true,
    options: [
      "Prior approval of members by ordinary resolution",
      "Prior approval of members by special resolution",
      "A board resolution passed at a meeting; members' approval not required",
      "No approval at all, since the value is under ₹1 crore"
    ],
    correct: 2,
    why: "It is a related party contract, so the board must approve it at a meeting — but it is at arm's length and in the ordinary course of business, so the members' resolution under Sec 188(1) is not triggered.",
    grades: [
      { label: "Hard", iv: "1d", bucket: 1 },
      { label: "Medium", iv: "6d", bucket: 3 },
      { label: "Easy", iv: "15d", bucket: 4 }
    ]
  }
];

const TOPICS = [
  { t: "Amalgamation & reconstruction", items: 42, att: 388, acc: 51, stuck: 64 },
  { t: "ITC reversal — Rules 42 & 43", items: 28, att: 301, acc: 55, stuck: 58 },
  { t: "Standard costing variances", items: 36, att: 412, acc: 63, stuck: 47 },
  { t: "AS 10 componentisation", items: 24, att: 266, acc: 71, stuck: 33 },
  { t: "Capital gains — indexation", items: 31, att: 244, acc: 74, stuck: 29 },
  { t: "Sec 188 related party", items: 18, att: 190, acc: 80, stuck: 21 },
  { t: "Ratio analysis basics", items: 22, att: 175, acc: 88, stuck: 12 }
];

const LIB = [
  ["AS 10 — Property, plant & equipment", "Questions", "Accounting Standards", 64, 9, "today", 74, "2d ago", true],
  ["AS 16 — Borrowing costs", "Questions", "Accounting Standards", 38, 0, "6d", 81, "4d ago", true],
  ["AS 22 — Deferred tax", "Flashcards", "Accounting Standards", 52, 3, "1d", 66, "1d ago", true],
  ["Overhead absorption bases", "Questions", "Cost Accounting", 41, 7, "today", 58, "3d ago", true],
  ["Standard costing — variances", "Questions", "Cost Accounting", 73, 0, "3d", 63, "5d ago", true],
  ["Marginal vs absorption costing", "Concept cards", "Cost Accounting", 19, 0, "2w", 79, "12d ago", true],
  ["Process costing — equivalent units", "Flashcards", "Cost Accounting", 44, 2, "1d", 70, "1d ago", false],
  ["Sec 188 — Related party", "Case studies", "Corporate Laws", 12, 6, "today", 61, "6d ago", true],
  ["Sec 185 & 186 — Loans to directors", "Questions", "Corporate Laws", 29, 0, "6d", 68, "7d ago", true],
  ["Board meetings & quorum", "Flashcards", "Corporate Laws", 34, 0, "1mo", 90, "22d ago", true],
  ["Charges & registration", "Notes", "Corporate Laws", 8, 0, "3mo", null, "31d ago", true],
  ["Capital gains — indexation", "Questions", "Direct Tax", 47, 4, "today", 72, "1d ago", false],
  ["Capital gains — exemptions 54 series", "Flashcards", "Direct Tax", 58, 0, "3d", 64, "3d ago", true],
  ["TDS rate chart FY 24–25", "Notes", "Direct Tax", 4, 0, "6mo+", null, "48d ago", true],
  ["Set-off & carry forward", "Questions", "Direct Tax", 33, 0, "2w", 77, "11d ago", true],
  ["Input tax credit — eligibility", "Concept cards", "GST", 16, 2, "today", 59, "9d ago", true],
  ["ITC reversal — Rules 42 & 43", "Questions", "GST", 27, 0, "1d", 55, "2d ago", true],
  ["Place of supply — services", "Flashcards", "GST", 45, 0, "6d", 71, "6d ago", true],
  ["E-way bill thresholds", "Notes", "GST", 6, 0, "1mo", null, "19d ago", false],
  ["Ratio analysis — my own cards", "Flashcards", "Financial Mgmt", 23, 0, "2w", 88, "14d ago", false],
  ["Cash flow statement — indirect", "Questions", "Financial Mgmt", 36, 0, "3d", 69, "4d ago", true],
  ["Cost of capital — WACC drills", "Questions", "Financial Mgmt", 40, 0, "6d", 66, "8d ago", true]
];

/* ─────────────────────────────────────────────────────────────
   PRIMITIVES
   ───────────────────────────────────────────────────────────── */

function Wordmark({ t, size = 22, tagline }) {
  return (
    <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap" }}>
      <span
        style={{
          fontFamily: SANS, fontWeight: 600, fontSize: size, letterSpacing: "-0.02em",
          backgroundImage: "linear-gradient(92deg,#3b82f6 0%,#8b5cf6 100%)",
          WebkitBackgroundClip: "text", backgroundClip: "text",
          WebkitTextFillColor: "transparent", color: "transparent"
        }}
      >
        RevisOp
      </span>
      {tagline && (
        <span style={{ fontFamily: SANS, fontSize: 12, fontWeight: 400, color: t.ink600 }}>
          {tagline}
        </span>
      )}
    </div>
  );
}

function Chip({ t, children, tone = "navy", title }) {
  const map = {
    navy: { bg: t.navy50, fg: t.navyText, bd: t.navy100 },
    due: { bg: t.bg2, fg: t.ink900, bd: t.borderStrong },
    green: { bg: t.green50, fg: t.green, bd: t.green },
    slate: { bg: t.slate50, fg: t.slate, bd: t.borderStrong }
  }[tone];
  return (
    <span
      title={title}
      style={{
        fontFamily: MONO, fontSize: 11.5, fontWeight: 500, lineHeight: 1,
        padding: "5px 7px", borderRadius: R_REC, background: map.bg,
        color: map.fg, border: `1px solid ${map.bd}`, whiteSpace: "nowrap",
        fontVariantNumeric: "tabular-nums", display: "inline-block"
      }}
    >
      {children}
    </span>
  );
}

function Label({ t, children, style }) {
  return (
    <div style={{
      fontFamily: SANS, fontSize: 11, fontWeight: 500, letterSpacing: "0.07em",
      textTransform: "uppercase", color: t.ink400, ...style
    }}>{children}</div>
  );
}

function Num({ t, children, size = 13, color }) {
  return (
    <span style={{
      fontFamily: MONO, fontSize: size, fontWeight: 500,
      fontVariantNumeric: "tabular-nums", color: color || t.ink900
    }}>{children}</span>
  );
}

/* THE SIGNATURE DEVICE — macro scale */
function ForwardLedger({ t, data, height = 72, compact = false, unit = "items" }) {
  const max = Math.max(...data);
  return (
    <div>
      <div style={{ display: "flex", alignItems: "flex-end", gap: 4, height }}>
        {data.map((v, i) => {
          const h = Math.max(4, Math.round((v / max) * (height - 18)));
          const now = i === 0;
          return (
            <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "flex-end" }}>
              <span style={{
                fontFamily: MONO, fontSize: 10.5, color: now ? t.ink900 : t.ink400,
                fontVariantNumeric: "tabular-nums", marginBottom: 4, fontWeight: now ? 500 : 400
              }}>{v}</span>
              <div style={{
                width: "78%", height: h, borderRadius: `${R_REC}px ${R_REC}px 0 0`,
                background: now ? t.navy : t.navy100,
                border: now ? "none" : `1px solid ${t.dark ? t.navy100 : "#d3d3ea"}`,
                borderBottom: "none"
              }} />
            </div>
          );
        })}
      </div>
      <div style={{ height: 1, background: t.borderStrong }} />
      <div style={{ display: "flex", gap: 4, marginTop: 5 }}>
        {BUCKETS.map((b, i) => (
          <div key={b} style={{
            flex: 1, textAlign: "center", fontFamily: MONO, fontSize: 10.5,
            color: i === 0 ? t.ink900 : t.ink400, fontWeight: i === 0 ? 500 : 400
          }}>{b}</div>
        ))}
      </div>
      {!compact && (
        <div style={{ fontFamily: SANS, fontSize: 11.5, color: t.ink400, marginTop: 8 }}>
          Scheduled {unit}, from now to six months out.
        </div>
      )}
    </div>
  );
}

/* THE SIGNATURE DEVICE — micro scale, inside a grade button */
function MicroRail({ t, bucket, active }) {
  const pct = (bucket / (BUCKETS.length - 1)) * 100;
  return (
    <div style={{ position: "relative", height: 10, width: "100%", marginTop: 10 }}>
      <div style={{ position: "absolute", top: 4, left: 0, right: 0, height: 1, background: active ? t.navy400 : t.borderStrong }} />
      {BUCKETS.map((b, i) => (
        <div key={b} style={{
          position: "absolute", top: 2, left: `${(i / (BUCKETS.length - 1)) * 100}%`,
          width: 1, height: 5, background: t.borderStrong, transform: "translateX(-0.5px)"
        }} />
      ))}
      <div style={{
        position: "absolute", top: 0, left: `${pct}%`, width: 9, height: 9,
        borderRadius: 5, background: t.navy, transform: "translateX(-4.5px)"
      }} />
    </div>
  );
}

function VerifiedEdge({ t, on }) {
  return <div style={{ width: 3, alignSelf: "stretch", background: on ? t.navy : "transparent", flexShrink: 0 }} />;
}

/* ─────────────────────────────────────────────────────────────
   SHELL A — navigation
   ───────────────────────────────────────────────────────────── */

const NAV_STUDENT = [
  { id: "today", label: "Today", icon: Home },
  { id: "library", label: "Library", icon: Layers },
  { id: "progress", label: "Progress", icon: BarChart3 },
  { id: "groups", label: "Groups", icon: Users }
];
const NAV_EDUCATOR = [
  { id: "today", label: "Today", icon: Home },
  { id: "library", label: "Library", icon: Layers },
  { id: "educator", label: "Class", icon: GraduationCap },
  { id: "groups", label: "Groups", icon: Users }
];
const NAV_ADMIN = [
  { id: "today", label: "Today", icon: Home },
  { id: "library", label: "Library", icon: Layers },
  { id: "admin", label: "Institute", icon: Building2 },
  { id: "groups", label: "Groups", icon: Users }
];

function BottomNav({ t, nav, active, go }) {
  return (
    <div style={{
      display: "flex", borderTop: `1px solid ${t.border}`, background: t.bg1,
      paddingBottom: 6, flexShrink: 0
    }}>
      {nav.map(n => {
        const on = n.id === active;
        const I = n.icon;
        return (
          <button key={n.id} onClick={() => go(n.id)} style={{
            flex: 1, border: "none", background: "transparent", cursor: "pointer",
            padding: "9px 0 5px", display: "flex", flexDirection: "column",
            alignItems: "center", gap: 3, color: on ? t.navyText : t.ink400
          }}>
            <I size={19} strokeWidth={on ? 2.2 : 1.7} />
            <span style={{ fontFamily: SANS, fontSize: 10.5, fontWeight: on ? 500 : 400 }}>{n.label}</span>
          </button>
        );
      })}
    </div>
  );
}

function SideRail({ t, nav, active, go, role }) {
  return (
    <div style={{
      width: 208, flexShrink: 0, borderRight: `1px solid ${t.border}`,
      background: t.bg1, padding: "20px 12px", display: "flex", flexDirection: "column"
    }}>
      <div style={{ padding: "0 8px 22px" }}>
        <Wordmark t={t} size={20} />
      </div>
      {nav.map(n => {
        const on = n.id === active;
        const I = n.icon;
        return (
          <button key={n.id} onClick={() => go(n.id)} style={{
            display: "flex", alignItems: "center", gap: 11, padding: "10px 10px",
            border: "none", borderRadius: R_REC, cursor: "pointer", marginBottom: 2,
            background: on ? t.navy50 : "transparent",
            color: on ? t.navyText : t.ink600, fontFamily: SANS, fontSize: 14,
            fontWeight: on ? 500 : 400, textAlign: "left", width: "100%"
          }}>
            <I size={17} strokeWidth={on ? 2.2 : 1.7} />{n.label}
          </button>
        );
      })}
      <div style={{ marginTop: "auto", padding: "0 10px" }}>
        <Label t={t}>Signed in as</Label>
        <div style={{ fontFamily: SANS, fontSize: 13, color: t.ink900, marginTop: 5 }}>
          {role === "educator" ? "CA Meera Raghavan" : "Ananya Deshpande"}
        </div>
        <div style={{ fontFamily: MONO, fontSize: 11, color: t.ink400, marginTop: 2 }}>
          {role === "educator" ? "Educator · Shreyas Classes" : "CA Inter · Group II"}
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   SCREEN 1 — TODAY
   ───────────────────────────────────────────────────────────── */

function DeckRow({ t, d, onStart }) {
  return (
    <div style={{ display: "flex", background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, overflow: "hidden" }}>
      <VerifiedEdge t={t} on={d.verified} />
      <div style={{ flex: 1, padding: "11px 13px", display: "flex", alignItems: "center", gap: 12, minHeight: 56, boxSizing: "border-box" }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: SANS, fontSize: 14.5, color: t.ink900, fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {d.name}
          </div>
          <div style={{ fontFamily: MONO, fontSize: 11, color: t.ink400, marginTop: 3 }}>
            {d.kind.toLowerCase()} · last seen {d.last}
          </div>
        </div>
        <Chip t={t} tone="due">{d.due} due</Chip>
        <button onClick={onStart} style={{
          border: `1px solid ${t.borderStrong}`, background: "transparent", color: t.ink600,
          borderRadius: R_REC, padding: "7px 10px", fontFamily: SANS, fontSize: 13, cursor: "pointer"
        }}>Open</button>
      </div>
    </div>
  );
}

function Heatmap({ t }) {
  const cells = [];
  for (let i = 0; i < 91; i++) {
    const v = (i * 37) % 11;
    const lvl = i > 87 ? 0 : v > 7 ? 3 : v > 4 ? 2 : v > 1 ? 1 : 0;
    cells.push(lvl);
  }
  const fill = [t.bg2, t.dark ? "#2f3a68" : "#d6d6ee", t.dark ? "#4c5aa8" : "#a9a9d8", t.navy];
  return (
    <div style={{ display: "grid", gridTemplateRows: "repeat(7,1fr)", gridAutoFlow: "column", gap: 3 }}>
      {cells.map((c, i) => (
        <div key={i} style={{ width: 9, height: 9, borderRadius: 2, background: fill[c] }} />
      ))}
    </div>
  );
}

function TodayHeader({ t, mobile }) {
  return (
    <div>
      <Label t={t}>Sunday, 2 August</Label>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginTop: 8 }}>
        <span style={{
          fontFamily: MONO, fontSize: mobile ? 40 : 46, fontWeight: 500,
          color: t.ink900, lineHeight: 1, fontVariantNumeric: "tabular-nums"
        }}>28</span>
        <span style={{ fontFamily: SANS, fontSize: mobile ? 17 : 19, color: t.ink600 }}>
          items due today
        </span>
      </div>
      <div style={{ fontFamily: SANS, fontSize: 13.5, color: t.ink400, marginTop: 7 }}>
        Nothing else is scheduled. Clear these and you are done for the day.
      </div>
    </div>
  );
}

function StartButton({ t, onClick, wide }) {
  return (
    <button onClick={onClick} style={{
      background: t.amber, color: t.amberInk, border: "none", borderRadius: R_OBJ,
      padding: "15px 20px", fontFamily: SANS, fontSize: 16, fontWeight: 500,
      cursor: "pointer", width: wide ? "100%" : "auto", display: "flex",
      alignItems: "center", justifyContent: "center", gap: 10, minHeight: 52
    }}>
      Start revising
      <span style={{ fontFamily: MONO, fontSize: 14, opacity: 0.75 }}>28 items · ~19 min</span>
    </button>
  );
}

function Stats({ t, row }) {
  const S = [["41", "day streak"], ["78%", "accuracy, 7d"], ["1,204", "items retained"]];
  return (
    <div style={{ display: "flex", gap: row ? 26 : 0, flexDirection: row ? "row" : "column" }}>
      {S.map(([n, l]) => (
        <div key={l} style={{ padding: row ? 0 : "10px 0", borderBottom: row ? "none" : `1px solid ${t.border}` }}>
          <div><Num t={t} size={20}>{n}</Num></div>
          <div style={{ fontFamily: SANS, fontSize: 12, color: t.ink400, marginTop: 2 }}>{l}</div>
        </div>
      ))}
    </div>
  );
}

function TodayScreen({ t, mobile, go }) {
  const start = () => go("study");
  if (mobile) {
    return (
      <div style={{ padding: 16, display: "flex", flexDirection: "column", gap: 20 }}>
        <Wordmark t={t} size={19} />
        <TodayHeader t={t} mobile />
        <StartButton t={t} onClick={start} wide />
        <div>
          <Label t={t} style={{ marginBottom: 9 }}>Due now, by deck</Label>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            {DUE_DECKS.map(d => <DeckRow key={d.name} t={t} d={d} onStart={start} />)}
          </div>
        </div>
        <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: 14 }}>
          <Label t={t} style={{ marginBottom: 11 }}>The week ahead</Label>
          <ForwardLedger t={t} data={TODAY_LOAD} height={62} />
        </div>
        <Stats t={t} row />
        <div style={{ height: 8 }} />
      </div>
    );
  }
  return (
    <div style={{ display: "flex", gap: 28, padding: "28px 32px", alignItems: "flex-start" }}>
      <div style={{ flex: 1, minWidth: 0, maxWidth: 720, display: "flex", flexDirection: "column", gap: 24 }}>
        <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: 24 }}>
          <TodayHeader t={t} />
          <StartButton t={t} onClick={start} />
        </div>
        <div>
          <Label t={t} style={{ marginBottom: 10 }}>Due now, by deck</Label>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            {DUE_DECKS.map(d => <DeckRow key={d.name} t={t} d={d} onStart={start} />)}
          </div>
        </div>
      </div>
      <div style={{ width: 320, flexShrink: 0, display: "flex", flexDirection: "column", gap: 18 }}>
        <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: 16 }}>
          <Label t={t} style={{ marginBottom: 12 }}>Forward ledger</Label>
          <ForwardLedger t={t} data={TODAY_LOAD} height={78} />
        </div>
        <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: 16 }}>
          <Label t={t} style={{ marginBottom: 12 }}>Last 13 weeks</Label>
          <Heatmap t={t} />
        </div>
        <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: "4px 16px 12px" }}>
          <Stats t={t} />
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   SCREEN 2 — SHELL B, THE STUDY LOOP
   ───────────────────────────────────────────────────────────── */

function ContextStrip({ t, item, onExit }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 10, padding: "12px 16px",
      borderBottom: `1px solid ${t.border}`, background: t.bg1, flexShrink: 0
    }}>
      <button onClick={onExit} aria-label="Leave revision" style={{
        border: "none", background: "transparent", cursor: "pointer", color: t.ink400,
        display: "flex", padding: 2
      }}><ArrowLeft size={18} /></button>
      <div style={{ minWidth: 0, flex: 1 }}>
        <div style={{
          fontFamily: MONO, fontSize: 11.5, color: t.ink400, overflow: "hidden",
          textOverflow: "ellipsis", whiteSpace: "nowrap"
        }}>
          {item.deck} · {item.topic}
        </div>
      </div>
      <Chip t={t} title="Current scheduling interval">→ {item.chip}</Chip>
      <span style={{ fontFamily: MONO, fontSize: 12, color: t.ink400, fontVariantNumeric: "tabular-nums" }}>
        {item.pos[0]}/{item.pos[1]}
      </span>
    </div>
  );
}

function CaseDock({ t, item, open, setOpen }) {
  return (
    <div style={{
      border: `1px solid ${t.border}`, borderLeft: `3px solid ${t.navy}`,
      background: t.navy50, borderRadius: 0, marginBottom: 16
    }}>
      <button onClick={() => setOpen(!open)} style={{
        width: "100%", display: "flex", alignItems: "center", gap: 10, padding: "11px 13px",
        border: "none", background: "transparent", cursor: "pointer", textAlign: "left"
      }}>
        <span style={{ fontFamily: MONO, fontSize: 11.5, color: t.navyText, fontWeight: 500 }}>
          {item.caseTitle}
        </span>
        <span style={{ fontFamily: MONO, fontSize: 11.5, color: t.ink400 }}>
          q{item.caseNo[0]} of {item.caseNo[1]}
        </span>
        <span style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 5, color: t.ink600, fontFamily: SANS, fontSize: 12.5 }}>
          {open ? "Hide passage" : "Read passage"}
          {open ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
        </span>
      </button>
      {open && (
        <div style={{ padding: "0 15px 15px" }}>
          <p style={{
            fontFamily: READ, fontSize: 15.5, lineHeight: 1.68, color: t.ink900, margin: 0
          }}>{item.passage}</p>
        </div>
      )}
    </div>
  );
}

function OptionRow({ t, text, index, state, onClick, disabled }) {
  const letters = "ABCD";
  let bd = t.border, bg = t.bg1, fg = t.ink900, badgeBg = t.bg2, badgeFg = t.ink600;
  if (state === "selected") { bd = t.navy400; bg = t.navy50; badgeBg = t.navy; badgeFg = t.dark ? "#0d0f24" : "#fff"; }
  if (state === "correct") { bd = t.green; bg = t.green50; badgeBg = t.green; badgeFg = "#fff"; }
  if (state === "missed") { bd = t.slate; bg = t.slate50; badgeBg = t.slate; badgeFg = "#fff"; }
  if (state === "dim") { fg = t.ink400; }
  return (
    <button onClick={onClick} disabled={disabled} style={{
      display: "flex", alignItems: "center", gap: 12, width: "100%", textAlign: "left",
      padding: "13px 14px", minHeight: 56, boxSizing: "border-box",
      border: `1px solid ${bd}`, background: bg, borderRadius: R_REC,
      cursor: disabled ? "default" : "pointer", color: fg, fontFamily: SANS, fontSize: 15,
      lineHeight: 1.4
    }}>
      <span style={{
        width: 24, height: 24, borderRadius: R_REC, background: badgeBg, color: badgeFg,
        display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
        fontFamily: MONO, fontSize: 12, fontWeight: 500
      }}>
        {state === "correct" ? <Check size={14} strokeWidth={3} />
          : state === "missed" ? <X size={14} strokeWidth={3} />
            : letters[index]}
      </span>
      <span style={{ flex: 1 }}>{text}</span>
      {state === "correct" && (
        <span style={{ fontFamily: SANS, fontSize: 11.5, fontWeight: 500, color: t.green, whiteSpace: "nowrap" }}>
          Correct answer
        </span>
      )}
      {state === "missed" && (
        <span style={{ fontFamily: SANS, fontSize: 11.5, fontWeight: 500, color: t.slate, whiteSpace: "nowrap" }}>
          You chose this
        </span>
      )}
    </button>
  );
}

function MatchZone({ t, item, pairs, setPairs, sel, setSel, revealed }) {
  const usedRight = Object.values(pairs);
  const pick = (li) => {
    if (revealed) return;
    if (pairs[li]) { const n = { ...pairs }; delete n[li]; setPairs(n); setSel(li); return; }
    setSel(sel === li ? null : li);
  };
  const assign = (k) => {
    if (revealed || sel === null) return;
    const n = { ...pairs };
    Object.keys(n).forEach(key => { if (n[key] === k) delete n[key]; });
    n[sel] = k;
    setPairs(n); setSel(null);
  };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      {item.left.map((l, li) => {
        const k = pairs[li];
        const ok = revealed && k === item.correct[li];
        const bad = revealed && k !== item.correct[li];
        const active = sel === li;
        let bd = t.border, bg = t.bg1;
        if (active) { bd = t.navy400; bg = t.navy50; }
        if (ok) { bd = t.green; bg = t.green50; }
        if (bad) { bd = t.slate; bg = t.slate50; }
        return (
          <div key={li}>
            <button onClick={() => pick(li)} disabled={revealed} style={{
              display: "flex", alignItems: "center", gap: 12, width: "100%", textAlign: "left",
              padding: "12px 14px", minHeight: 54, boxSizing: "border-box",
              border: `1px solid ${bd}`, background: bg, borderRadius: R_REC,
              cursor: revealed ? "default" : "pointer", fontFamily: SANS, fontSize: 15, color: t.ink900
            }}>
              <span style={{
                width: 24, height: 24, borderRadius: R_REC, flexShrink: 0,
                display: "flex", alignItems: "center", justifyContent: "center",
                background: ok ? t.green : bad ? t.slate : k ? t.navy : t.bg2,
                color: (ok || bad || k) ? (t.dark && k && !ok && !bad ? "#0d0f24" : "#fff") : t.ink400,
                fontFamily: MONO, fontSize: 12, fontWeight: 500
              }}>
                {ok ? <Check size={14} strokeWidth={3} /> : bad ? <X size={14} strokeWidth={3} /> : (k || "—")}
              </span>
              <span style={{ flex: 1 }}>{l}</span>
              {!revealed && active && (
                <span style={{ fontFamily: SANS, fontSize: 11.5, color: t.navyText }}>pick a match →</span>
              )}
            </button>
            {bad && (
              <div style={{
                display: "flex", gap: 7, alignItems: "baseline", padding: "7px 14px 3px",
                fontFamily: SANS, fontSize: 12.5, color: t.ink600
              }}>
                <span style={{ fontWeight: 500, color: t.green }}>Correct answer:</span>
                <span>{item.correct[li]} — {item.right.find(r => r.k === item.correct[li]).v}</span>
              </div>
            )}
          </div>
        );
      })}
      <div style={{ height: 1, background: t.border, margin: "8px 0 4px" }} />
      <Label t={t} style={{ marginBottom: 2 }}>{revealed ? "Options" : "Tap a row above, then its match"}</Label>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 7 }}>
        {item.right.map(r => {
          const used = usedRight.includes(r.k);
          return (
            <button key={r.k} onClick={() => assign(r.k)} disabled={revealed || sel === null} style={{
              display: "flex", alignItems: "center", gap: 8, padding: "10px 12px", minHeight: 48,
              boxSizing: "border-box", borderRadius: R_REC,
              border: `1px solid ${sel !== null && !revealed ? t.navy400 : t.border}`,
              background: used ? t.bg2 : t.bg1, opacity: used && !revealed ? 0.55 : 1,
              cursor: revealed || sel === null ? "default" : "pointer",
              fontFamily: SANS, fontSize: 14, color: t.ink900, flex: "1 1 44%", textAlign: "left"
            }}>
              <span style={{ fontFamily: MONO, fontSize: 12, fontWeight: 500, color: t.navyText }}>{r.k}</span>
              <span>{r.v}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function Explanation({ t, item }) {
  return (
    <div style={{
      marginTop: 14, padding: "13px 15px", background: t.bg2, borderRadius: R_REC,
      borderLeft: `3px solid ${t.navy}`
    }}>
      <Label t={t} style={{ marginBottom: 6 }}>Why</Label>
      <p style={{ fontFamily: READ, fontSize: 15, lineHeight: 1.6, color: t.ink900, margin: 0 }}>{item.why}</p>
      <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 10, color: t.ink400 }}>
        <ShieldCheck size={13} />
        <span style={{ fontFamily: MONO, fontSize: 11 }}>verified · {item.verified}</span>
      </div>
    </div>
  );
}

function GradeRow({ t, item, onGrade, mobile }) {
  return (
    <div>
      <div style={{
        fontFamily: SANS, fontSize: 13, color: t.ink600, marginBottom: 11, textAlign: "center"
      }}>
        How hard was recalling that?
      </div>
      <div style={{ display: "flex", gap: 10 }}>
        {item.grades.map((g, i) => (
          <button key={g.label} onClick={() => onGrade(g)} style={{
            flex: 1, minHeight: mobile ? 86 : 92, padding: "13px 10px 12px",
            border: `1.5px solid ${t.navy400}`, background: t.bg1, borderRadius: R_OBJ,
            cursor: "pointer", display: "flex", flexDirection: "column",
            alignItems: "center", justifyContent: "center", gap: 2
          }}>
            <span style={{ fontFamily: SANS, fontSize: 14.5, fontWeight: 500, color: t.ink900 }}>{g.label}</span>
            <span style={{
              fontFamily: MONO, fontSize: mobile ? 19 : 21, fontWeight: 500, color: t.navyText,
              fontVariantNumeric: "tabular-nums", lineHeight: 1.25
            }}>→ {g.iv}</span>
            <MicroRail t={t} bucket={g.bucket} active />
          </button>
        ))}
      </div>
    </div>
  );
}

function PostedForward({ t, posted }) {
  const [go, setGo] = useState(false);
  useEffect(() => {
    const reduce = typeof window !== "undefined" && window.matchMedia
      && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const id = setTimeout(() => setGo(true), reduce ? 0 : 40);
    return () => clearTimeout(id);
  }, []);
  const pct = (posted.bucket / (BUCKETS.length - 1)) * 100;
  return (
    <div style={{ padding: "18px 4px 6px" }}>
      <div style={{ textAlign: "center", fontFamily: SANS, fontSize: 14, color: t.ink600, marginBottom: 18 }}>
        Posted forward · returns in <Num t={t} size={14} color={t.ink900}>{posted.iv}</Num>
      </div>
      <div style={{ position: "relative", height: 26 }}>
        <div style={{ position: "absolute", top: 12, left: 0, right: 0, height: 1, background: t.borderStrong }} />
        {BUCKETS.map((b, i) => (
          <div key={b} style={{
            position: "absolute", top: 8, left: `${(i / (BUCKETS.length - 1)) * 100}%`,
            width: 1, height: 6, background: t.borderStrong
          }} />
        ))}
        <div style={{
          position: "absolute", top: 5, left: go ? `${pct}%` : "0%",
          width: 15, height: 15, borderRadius: R_REC, background: t.navy,
          transform: "translateX(-7.5px)", transition: "left 420ms cubic-bezier(.2,.7,.3,1)"
        }} />
      </div>
      <div style={{ display: "flex", marginTop: 6 }}>
        {BUCKETS.map((b, i) => (
          <div key={b} style={{
            flex: 1, textAlign: i === 0 ? "left" : i === BUCKETS.length - 1 ? "right" : "center",
            fontFamily: MONO, fontSize: 10.5, color: t.ink400
          }}>{b}</div>
        ))}
      </div>
    </div>
  );
}

function StudyScreen({ t, mobile, go }) {
  const [idx, setIdx] = useState(0);
  const [phase, setPhase] = useState("attempt"); // attempt | truth | posting
  const [choice, setChoice] = useState(null);
  const [pairs, setPairs] = useState({});
  const [sel, setSel] = useState(null);
  const [caseOpen, setCaseOpen] = useState(true);
  const [posted, setPosted] = useState(null);
  const [done, setDone] = useState(false);
  const timer = useRef(null);
  useEffect(() => () => clearTimeout(timer.current), []);

  const item = ITEMS[idx];
  const revealed = phase !== "attempt";
  const ready = item.type === "match" ? Object.keys(pairs).length === 4 : choice !== null;

  const reset = () => { setChoice(null); setPairs({}); setSel(null); setCaseOpen(true); };
  const grade = (g) => {
    setPosted({ iv: g.iv, bucket: g.bucket });
    setPhase("posting");
    timer.current = setTimeout(() => {
      setPosted(null);
      if (idx === ITEMS.length - 1) { setDone(true); return; }
      setIdx(idx + 1); setPhase("attempt"); reset();
    }, 1250);
  };
  const restart = () => { setIdx(0); setPhase("attempt"); reset(); setDone(false); };

  if (done) {
    return (
      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 30, gap: 18 }}>
        <div style={{ fontFamily: MONO, fontSize: 40, fontWeight: 500, color: t.ink900 }}>3/3</div>
        <div style={{ fontFamily: SANS, fontSize: 17, color: t.ink900, textAlign: "center" }}>
          Ledger cleared for this deck.
        </div>
        <div style={{ fontFamily: SANS, fontSize: 13.5, color: t.ink400, textAlign: "center", maxWidth: 320 }}>
          The next 25 items in today's queue are waiting. Nothing here returns before tomorrow.
        </div>
        <div style={{ display: "flex", gap: 10, marginTop: 6 }}>
          <button onClick={restart} style={{
            border: `1px solid ${t.borderStrong}`, background: "transparent", color: t.ink600,
            borderRadius: R_REC, padding: "12px 16px", fontFamily: SANS, fontSize: 14, cursor: "pointer"
          }}>Run the loop again</button>
          <button onClick={() => go("today")} style={{
            border: "none", background: t.amber, color: t.amberInk, borderRadius: R_OBJ,
            padding: "12px 18px", fontFamily: SANS, fontSize: 15, fontWeight: 500, cursor: "pointer"
          }}>Back to today</button>
        </div>
      </div>
    );
  }

  const stemStyle = {
    fontFamily: item.long ? READ : SANS,
    fontSize: item.long ? 16.5 : 18,
    lineHeight: item.long ? 1.62 : 1.42,
    fontWeight: item.long ? 400 : 500,
    color: t.ink900, margin: "0 0 18px"
  };

  const body = (
    <>
      {item.type === "case" && <CaseDock t={t} item={item} open={caseOpen} setOpen={setCaseOpen} />}
      <p style={stemStyle}>{item.stem}</p>
      {item.type === "match" ? (
        <MatchZone t={t} item={item} pairs={pairs} setPairs={setPairs} sel={sel} setSel={setSel} revealed={revealed} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {item.options.map((o, i) => {
            let state = "idle";
            if (!revealed) state = choice === i ? "selected" : "idle";
            else if (i === item.correct) state = "correct";
            else if (i === choice) state = "missed";
            else state = "dim";
            return (
              <OptionRow key={i} t={t} text={o} index={i} state={state}
                disabled={revealed} onClick={() => setChoice(i)} />
            );
          })}
        </div>
      )}
      {revealed && <Explanation t={t} item={item} />}
    </>
  );

  const bar = phase === "posting" && posted
    ? <PostedForward t={t} posted={posted} />
    : phase === "truth"
      ? <GradeRow t={t} item={item} onGrade={grade} mobile={mobile} />
      : (
        <button onClick={() => ready && setPhase("truth")} disabled={!ready} style={{
          width: "100%", minHeight: 54, border: "none", borderRadius: R_OBJ,
          background: ready ? t.amber : t.bg2, color: ready ? t.amberInk : t.ink400,
          fontFamily: SANS, fontSize: 16, fontWeight: 500,
          cursor: ready ? "pointer" : "default"
        }}>
          {ready ? "Check answer" : item.type === "match" ? "Match all four to continue" : "Choose an answer"}
        </button>
      );

  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", background: t.bg0, minHeight: 0 }}>
      <ContextStrip t={t} item={item} onExit={() => go("today")} />
      <div style={{ flex: 1, overflowY: "auto", minHeight: 0 }}>
        <div style={{
          maxWidth: mobile ? "none" : 660, margin: "0 auto",
          padding: mobile ? "18px 16px 24px" : "30px 24px 34px"
        }}>
          <div style={{
            background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_OBJ,
            padding: mobile ? 16 : 24, boxShadow: t.shadow
          }}>{body}</div>
        </div>
      </div>
      <div style={{
        borderTop: `1px solid ${t.border}`, background: t.bg1, boxShadow: t.shadowBar,
        padding: mobile ? "12px 16px 16px" : "16px 24px 20px", flexShrink: 0
      }}>
        <div style={{ maxWidth: mobile ? "none" : 660, margin: "0 auto" }}>{bar}</div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   SCREEN 3 — EDUCATOR
   ───────────────────────────────────────────────────────────── */

function Kpi({ t, n, l, sub }) {
  return (
    <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: "13px 15px", flex: 1, minWidth: 130 }}>
      <Num t={t} size={26}>{n}</Num>
      <div style={{ fontFamily: SANS, fontSize: 12.5, color: t.ink600, marginTop: 3 }}>{l}</div>
      {sub && <div style={{ fontFamily: MONO, fontSize: 11, color: t.ink400, marginTop: 3 }}>{sub}</div>}
    </div>
  );
}

function StuckBar({ t, pct }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
      <div style={{ width: 54, height: 6, background: t.bg2, borderRadius: 3, overflow: "hidden" }}>
        <div style={{ width: `${pct}%`, height: "100%", background: pct > 50 ? t.navy : t.navy400 }} />
      </div>
      <Num t={t} size={12} color={pct > 50 ? t.ink900 : t.ink400}>{pct}%</Num>
    </div>
  );
}

function EducatorScreen({ t, mobile }) {
  const head = (
    <div>
      <Label t={t}>Shreyas Classes · CA Inter Group II</Label>
      <div style={{ fontFamily: SANS, fontSize: mobile ? 21 : 25, fontWeight: 600, color: t.ink900, marginTop: 6 }}>
        Batch 2026-A
      </div>
      <div style={{ fontFamily: SANS, fontSize: 13.5, color: t.ink400, marginTop: 6 }}>
        156 students · your verified content · last 7 days
      </div>
    </div>
  );

  const kpis = (
    <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
      <Kpi t={t} n="128" l="students revised" sub="of 156 enrolled" />
      <Kpi t={t} n="4,812" l="attempts" sub="+9% vs last week" />
      <Kpi t={t} n="68%" l="median accuracy" sub="target 75%" />
      <Kpi t={t} n="312" l="verified items" sub="14 added this week" />
    </div>
  );

  const rail = (
    <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 12 }}>
        <Label t={t}>Cohort forward ledger</Label>
        <span style={{ fontFamily: MONO, fontSize: 11, color: t.ink400 }}>1,995 scheduled</span>
      </div>
      <ForwardLedger t={t} data={COHORT_LOAD} height={mobile ? 66 : 88} unit="items across the batch" />
      <div style={{
        marginTop: 12, padding: "10px 12px", background: t.bg2, borderRadius: R_REC,
        borderLeft: `3px solid ${t.navy}`, fontFamily: SANS, fontSize: 13, color: t.ink900, lineHeight: 1.5
      }}>
        Mass is piling up at 3d instead of moving right. The batch keeps re-earning short
        intervals on the same material — a comprehension problem, not an effort problem.
      </div>
    </div>
  );

  const table = (
    <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, overflow: "hidden" }}>
      <div style={{ padding: "12px 15px", borderBottom: `1px solid ${t.border}`, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <Label t={t}>Your topics, hardest first</Label>
        <span style={{ fontFamily: MONO, fontSize: 11, color: t.ink400 }}>compact · 44px</span>
      </div>
      {!mobile && (
        <div style={{ display: "flex", padding: "8px 15px", borderBottom: `1px solid ${t.border}`, background: t.bg0 }}>
          <div style={{ flex: 1 }}><Label t={t}>Topic</Label></div>
          <div style={{ width: 62, textAlign: "right" }}><Label t={t}>Items</Label></div>
          <div style={{ width: 78, textAlign: "right" }}><Label t={t}>Attempts</Label></div>
          <div style={{ width: 78, textAlign: "right" }}><Label t={t}>Accuracy</Label></div>
          <div style={{ width: 118, textAlign: "right" }}><Label t={t}>Stuck ≤3d</Label></div>
        </div>
      )}
      {TOPICS.map((r, i) => (
        <div key={r.t} style={{
          display: "flex", alignItems: "center", padding: "0 15px", height: 44,
          borderBottom: i === TOPICS.length - 1 ? "none" : `1px solid ${t.border}`,
          background: i % 2 ? (t.dark ? t.bg0 : "#fcfcfe") : "transparent"
        }}>
          <div style={{ flex: 1, minWidth: 0, fontFamily: SANS, fontSize: 14, color: t.ink900, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {r.t}
          </div>
          {!mobile && <div style={{ width: 62, textAlign: "right" }}><Num t={t} size={13} color={t.ink400}>{r.items}</Num></div>}
          {!mobile && <div style={{ width: 78, textAlign: "right" }}><Num t={t} size={13} color={t.ink400}>{r.att}</Num></div>}
          <div style={{ width: mobile ? 54 : 78, textAlign: "right" }}>
            <Num t={t} size={13} color={r.acc < 60 ? t.ink900 : t.ink600}>{r.acc}%</Num>
          </div>
          <div style={{ width: 118, display: "flex", justifyContent: "flex-end" }}>
            <StuckBar t={t} pct={r.stuck} />
          </div>
        </div>
      ))}
    </div>
  );

  const attention = (
    <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, padding: 16 }}>
      <Label t={t} style={{ marginBottom: 11 }}>Needs you this week</Label>
      {[
        ["Amalgamation & reconstruction", "64% of the batch is stuck under 3 days. Consider re-teaching or splitting the items."],
        ["12 students inactive", "No revision in 6+ days. Nudge or reassign."],
        ["3 items flagged", "Students reported the answer key on Rule 42 examples."]
      ].map(([h, s], i) => (
        <div key={h} style={{ padding: "11px 0", borderTop: i ? `1px solid ${t.border}` : "none" }}>
          <div style={{ fontFamily: SANS, fontSize: 14, fontWeight: 500, color: t.ink900 }}>{h}</div>
          <div style={{ fontFamily: SANS, fontSize: 12.5, color: t.ink400, marginTop: 3, lineHeight: 1.5 }}>{s}</div>
        </div>
      ))}
      <button style={{
        marginTop: 12, width: "100%", minHeight: 48, border: "none", borderRadius: R_OBJ,
        background: t.amber, color: t.amberInk, fontFamily: SANS, fontSize: 15, fontWeight: 500, cursor: "pointer"
      }}>Publish 6 draft items</button>
    </div>
  );

  if (mobile) {
    return (
      <div style={{ padding: 16, display: "flex", flexDirection: "column", gap: 18 }}>
        {head}{kpis}{rail}{table}{attention}<div style={{ height: 8 }} />
      </div>
    );
  }
  return (
    <div style={{ display: "flex", gap: 24, padding: "26px 30px", alignItems: "flex-start" }}>
      <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 20 }}>
        {head}{kpis}{rail}{table}
      </div>
      <div style={{ width: 320, flexShrink: 0 }}>{attention}</div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   SCREEN 4 — LIBRARY
   ───────────────────────────────────────────────────────────── */

const DENSITY = {
  comfortable: { h: 56, fs: 15, meta: true, label: "Comfortable" },
  compact: { h: 44, fs: 14, meta: false, label: "Compact" },
  data: { h: 36, fs: 13, meta: false, label: "Data" }
};

function LibraryScreen({ t, mobile }) {
  const [density, setDensity] = useState(mobile ? "comfortable" : "compact");
  const [filter, setFilter] = useState("All");
  const [q, setQ] = useState("");
  const d = DENSITY[density];
  const types = ["All", "Questions", "Flashcards", "Case studies", "Concept cards", "Notes"];
  const rows = LIB.filter(r => (filter === "All" || r[1] === filter) &&
    (q === "" || (r[0] + r[2]).toLowerCase().includes(q.toLowerCase())));
  const showCols = density === "data" && !mobile ? 3 : density === "compact" && !mobile ? 2 : 1;

  return (
    <div style={{ padding: mobile ? 16 : "26px 30px", display: "flex", flexDirection: "column", gap: 16 }}>
      <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
        <div>
          <Label t={t}>Library</Label>
          <div style={{ fontFamily: SANS, fontSize: mobile ? 21 : 25, fontWeight: 600, color: t.ink900, marginTop: 6 }}>
            {rows.length} decks
          </div>
        </div>
        <div style={{ display: "flex", gap: 4, background: t.bg2, padding: 3, borderRadius: R_REC }}>
          {Object.keys(DENSITY).filter(k => !(mobile && k === "data")).map(k => (
            <button key={k} onClick={() => setDensity(k)} style={{
              border: "none", borderRadius: 3, padding: "7px 11px", cursor: "pointer",
              background: density === k ? t.bg1 : "transparent",
              color: density === k ? t.ink900 : t.ink400,
              fontFamily: MONO, fontSize: 11.5, fontWeight: 500,
              boxShadow: density === k ? t.shadow : "none"
            }}>{DENSITY[k].label}</button>
          ))}
        </div>
      </div>

      <div style={{
        display: "flex", alignItems: "center", gap: 9, background: t.bg1,
        border: `1px solid ${t.border}`, borderRadius: R_REC, padding: "0 12px", minHeight: 46
      }}>
        <Search size={16} color={t.ink400} />
        <input value={q} onChange={e => setQ(e.target.value)} placeholder="Search decks and topics"
          style={{
            flex: 1, border: "none", outline: "none", background: "transparent",
            fontFamily: SANS, fontSize: 15, color: t.ink900, padding: "12px 0"
          }} />
        {q && <button onClick={() => setQ("")} style={{ border: "none", background: "transparent", cursor: "pointer", color: t.ink400, display: "flex" }}><X size={15} /></button>}
      </div>

      <div style={{ display: "flex", gap: 6, overflowX: "auto", paddingBottom: 2 }}>
        {types.map(ty => (
          <button key={ty} onClick={() => setFilter(ty)} style={{
            border: `1px solid ${filter === ty ? t.navy400 : t.border}`,
            background: filter === ty ? t.navy50 : t.bg1,
            color: filter === ty ? t.navyText : t.ink600,
            borderRadius: R_REC, padding: "8px 11px", minHeight: 38, cursor: "pointer",
            fontFamily: SANS, fontSize: 13, whiteSpace: "nowrap", flexShrink: 0
          }}>{ty}</button>
        ))}
      </div>

      <div style={{ background: t.bg1, border: `1px solid ${t.border}`, borderRadius: R_REC, overflow: "hidden" }}>
        {!mobile && (
          <div style={{ display: "flex", alignItems: "center", padding: "0 14px 0 0", height: 34, borderBottom: `1px solid ${t.border}`, background: t.bg0 }}>
            <div style={{ width: 3 }} />
            <div style={{ flex: 1, paddingLeft: 14 }}><Label t={t}>Deck</Label></div>
            {showCols >= 2 && <div style={{ width: 118 }}><Label t={t}>Type</Label></div>}
            {showCols >= 3 && <div style={{ width: 130 }}><Label t={t}>Subject</Label></div>}
            {showCols >= 2 && <div style={{ width: 56, textAlign: "right" }}><Label t={t}>Items</Label></div>}
            {showCols >= 3 && <div style={{ width: 70, textAlign: "right" }}><Label t={t}>Accuracy</Label></div>}
            <div style={{ width: 66, textAlign: "right" }}><Label t={t}>Due</Label></div>
            <div style={{ width: 86, textAlign: "right", paddingRight: 4 }}><Label t={t}>Next</Label></div>
            {showCols >= 3 && <div style={{ width: 86, textAlign: "right" }}><Label t={t}>Last seen</Label></div>}
          </div>
        )}
        {rows.map((r, i) => {
          const [title, type, subject, items, due, next, acc, last, verified] = r;
          return (
            <div key={title} style={{
              display: "flex", alignItems: "center", height: d.h, paddingRight: 14,
              borderBottom: i === rows.length - 1 ? "none" : `1px solid ${t.border}`,
              background: i % 2 ? (t.dark ? t.bg0 : "#fcfcfe") : "transparent", cursor: "pointer"
            }}>
              <div style={{ width: 3, height: "100%", background: verified ? t.navy : "transparent", flexShrink: 0 }} />
              <div style={{ flex: 1, minWidth: 0, paddingLeft: 11 }}>
                <div style={{
                  fontFamily: SANS, fontSize: d.fs, color: t.ink900, fontWeight: 400,
                  overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap"
                }}>{title}</div>
                {d.meta && (
                  <div style={{ fontFamily: MONO, fontSize: 11, color: t.ink400, marginTop: 2 }}>
                    {subject.toLowerCase()} · {type.toLowerCase()} · {items} items
                  </div>
                )}
              </div>
              {showCols >= 2 && <div style={{ width: 118, fontFamily: SANS, fontSize: 12.5, color: t.ink400 }}>{type}</div>}
              {showCols >= 3 && <div style={{ width: 130, fontFamily: SANS, fontSize: 12.5, color: t.ink400, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{subject}</div>}
              {showCols >= 2 && <div style={{ width: 56, textAlign: "right" }}><Num t={t} size={12.5} color={t.ink400}>{items}</Num></div>}
              {showCols >= 3 && <div style={{ width: 70, textAlign: "right" }}><Num t={t} size={12.5} color={t.ink400}>{acc ? acc + "%" : "—"}</Num></div>}
              <div style={{ width: 66, textAlign: "right" }}>
                {due > 0
                  ? <Num t={t} size={12.5} color={t.ink900}>{due} due</Num>
                  : <Num t={t} size={12.5} color={t.ink400}>—</Num>}
              </div>
              <div style={{ width: 86, textAlign: "right", paddingRight: 4 }}>
                <Chip t={t} tone={next === "today" ? "due" : "navy"} title="Next scheduled review">
                  {next === "today" ? "now" : "→ " + next}
                </Chip>
              </div>
              {showCols >= 3 && <div style={{ width: 86, textAlign: "right", fontFamily: MONO, fontSize: 11.5, color: t.ink400 }}>{last}</div>}
            </div>
          );
        })}
        {rows.length === 0 && (
          <div style={{ padding: "34px 16px", textAlign: "center" }}>
            <div style={{ fontFamily: SANS, fontSize: 15, color: t.ink900 }}>No decks match that search.</div>
            <div style={{ fontFamily: SANS, fontSize: 13, color: t.ink400, marginTop: 6 }}>
              Clear the filter, or create a deck and start adding items.
            </div>
          </div>
        )}
      </div>

      <div style={{
        display: "flex", alignItems: "center", gap: 10, padding: "11px 13px",
        border: `1px solid ${t.border}`, borderRadius: R_REC, background: t.bg1
      }}>
        <div style={{ width: 3, height: 22, background: t.navy }} />
        <span style={{ fontFamily: SANS, fontSize: 12.5, color: t.ink600 }}>
          Navy edge = verified by your institute. Unmarked decks are your own.
        </span>
        <button style={{
          marginLeft: "auto", display: "flex", alignItems: "center", gap: 6,
          border: `1px solid ${t.border}`, background: "transparent", color: t.danger,
          borderRadius: R_REC, padding: "7px 10px", fontFamily: SANS, fontSize: 12.5, cursor: "pointer"
        }}><Trash2 size={13} /> Delete deck</button>
      </div>
      <div style={{ height: mobile ? 6 : 0 }} />
    </div>
  );
}

/* ─────────────────────────────────────────────────────────────
   HARNESS
   ───────────────────────────────────────────────────────────── */

const SCREENS = [
  { id: "today", label: "Today" },
  { id: "study", label: "Study loop" },
  { id: "educator", label: "Educator" },
  { id: "library", label: "Library" }
];

export default function RevisOpPass2() {
  const [mode, setMode] = useState("light");
  const [viewport, setViewport] = useState("desktop");
  const [screen, setScreen] = useState("today");
  const t = mode === "light" ? LIGHT : DARK;
  const mobile = viewport === "mobile";

  useEffect(() => {
    const l = document.createElement("link");
    l.rel = "stylesheet";
    l.href = "https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&family=Literata:opsz,wght@7..72,400;7..72,500&display=swap";
    document.head.appendChild(l);
    return () => { document.head.removeChild(l); };
  }, []);

  const role = screen === "educator" ? "educator" : "student";
  const nav = role === "educator" ? NAV_EDUCATOR : NAV_STUDENT;
  const navActive = screen === "study" ? "today" : screen;
  const go = (id) => { if (SCREENS.some(s => s.id === id) || id === "study") setScreen(id); };

  const content =
    screen === "today" ? <TodayScreen t={t} mobile={mobile} go={go} />
      : screen === "study" ? <StudyScreen t={t} mobile={mobile} go={go} />
        : screen === "educator" ? <EducatorScreen t={t} mobile={mobile} />
          : <LibraryScreen t={t} mobile={mobile} />;

  const inStudy = screen === "study";

  const app = mobile ? (
    <div style={{
      width: 390, margin: "0 auto", height: 800, background: t.bg0,
      border: `1px solid ${t.borderStrong}`, borderRadius: 22, overflow: "hidden",
      display: "flex", flexDirection: "column", boxShadow: t.shadow
    }}>
      {inStudy ? content : (
        <>
          <div style={{ flex: 1, overflowY: "auto", minHeight: 0 }}>{content}</div>
          <BottomNav t={t} nav={nav} active={navActive} go={go} />
        </>
      )}
    </div>
  ) : (
    <div style={{
      background: t.bg0, border: `1px solid ${t.borderStrong}`, borderRadius: 8,
      overflow: "hidden", display: "flex", minHeight: 720, maxHeight: 860
    }}>
      {!inStudy && <SideRail t={t} nav={nav} active={navActive} go={go} role={role} />}
      <div style={{ flex: 1, minWidth: 0, overflowY: "auto", display: "flex", flexDirection: "column" }}>
        {content}
      </div>
    </div>
  );

  return (
    <div style={{
      background: mode === "light" ? "#eceef3" : "#07081a", minHeight: "100vh",
      padding: "18px 16px 40px", fontFamily: SANS
    }}>
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 10, flexWrap: "wrap",
          marginBottom: 16, paddingBottom: 14,
          borderBottom: `1px solid ${mode === "light" ? "#d7dae2" : "#1c1e3a"}`
        }}>
          <span style={{
            fontFamily: MONO, fontSize: 11, letterSpacing: "0.08em", textTransform: "uppercase",
            color: mode === "light" ? "#6b7280" : "#7b83a3", marginRight: 4
          }}>Pass 2 · review harness</span>
          <div style={{ display: "flex", gap: 4 }}>
            {SCREENS.map(s => (
              <button key={s.id} onClick={() => setScreen(s.id)} style={{
                border: `1px solid ${screen === s.id ? "transparent" : (mode === "light" ? "#d7dae2" : "#252846")}`,
                background: screen === s.id ? (mode === "light" ? "#1e1b4b" : "#a5b4fc") : "transparent",
                color: screen === s.id ? (mode === "light" ? "#fff" : "#0d0f24") : (mode === "light" ? "#374151" : "#9aa1b8"),
                borderRadius: 4, padding: "7px 11px", fontFamily: SANS, fontSize: 13, cursor: "pointer"
              }}>{s.label}</button>
            ))}
          </div>
          <div style={{ marginLeft: "auto", display: "flex", gap: 4 }}>
            <button onClick={() => setViewport(viewport === "mobile" ? "desktop" : "mobile")} style={{
              display: "flex", alignItems: "center", gap: 6, border: `1px solid ${mode === "light" ? "#d7dae2" : "#252846"}`,
              background: "transparent", color: mode === "light" ? "#374151" : "#9aa1b8",
              borderRadius: 4, padding: "7px 10px", fontFamily: MONO, fontSize: 12, cursor: "pointer"
            }}>
              {mobile ? <Smartphone size={14} /> : <Monitor size={14} />}
              {mobile ? "390px" : "desktop"}
            </button>
            <button onClick={() => setMode(mode === "light" ? "dark" : "light")} aria-label="Toggle dark mode" style={{
              display: "flex", alignItems: "center", border: `1px solid ${mode === "light" ? "#d7dae2" : "#252846"}`,
              background: "transparent", color: mode === "light" ? "#374151" : "#9aa1b8",
              borderRadius: 4, padding: "7px 9px", cursor: "pointer"
            }}>{mode === "light" ? <Moon size={14} /> : <Sun size={14} />}</button>
          </div>
        </div>
        {app}
        <div style={{
          fontFamily: MONO, fontSize: 11, color: mode === "light" ? "#8b8fa0" : "#5c6285",
          marginTop: 12, lineHeight: 1.7
        }}>
          study loop is live: choose → check answer → grade → watch the item post forward. three
          question types in sequence. library density toggle is live. dark mode is live.
        </div>
      </div>
    </div>
  );
}
