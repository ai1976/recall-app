# RevisOp Public Pages — UX & Conversion Audit

**Prepared:** 05/07/2026
**Scope:** 11 public (logged-out) pages, desktop (1280px) + mobile (390px) — 22 screenshots total, per `docs/active/design-review-screenshot-checklist.md`.
**Reviewer stance:** senior product designer / CRO consultant, pre-Phase-6 baseline.

**Methodology note:** This audit is built from rendered screenshots, not live devtools inspection. Where I comment on spacing, alignment, or type scale, treat it as a trained visual estimate ("this gap reads tighter than that gap"), not a measured pixel value — I don't have inspector access to this build. Everything about copy, hierarchy, IA, color, and content is a direct observation from the images. No analytics or heatmap data was available, so funnel drop-off claims and A/B suggestions are hypotheses to test, not measured facts.

**Canonical page map** (filenames per the checklist):

| # | Page |
|---|---|
| 01 | Landing (`/`) |
| 02 | For Institutes & Educators (`/educators`) |
| 03 | Student Guide (`/guide`) |
| 04 | Login |
| 05 | Signup |
| 06 | Forgot Password |
| 07 | Public Study Set Preview |
| 08 | Public Note Preview |
| 09 | Group Join preview |
| 10 | Terms of Service |
| 11 | Privacy Policy |

---

## 1. Executive Summary

RevisOp's public surface is unusually solid for an 11-page beta site — real content in the hero (an actual flashcard, not a mockup), honest specific numbers, a clean auth flow, and a genuinely well-built viral loop (shared notes/decks/groups gate on signup with a real "here's what you get" pitch, not just a paywall). This isn't a site that needs a redesign. It needs a punch-list pass, because the actual problems aren't "the design is bad" — they're "the details don't yet match the ambition of the idea." Three patterns recur across almost every finding below:

1. **Self-inconsistency undermines trust more than any single weak page does.** The landing page contradicts its own stats (2,183 flashcards in the hero, 693 flashcards two sections later). The Institutes page's CTA buttons render in a washed-out color that reads as disabled. The nav promises "For Educators" and delivers institute content. None of these are hard problems — they're the kind of thing that slips through when pages are built independently and never proofread against each other — but this exact audience (accounting/professional-exam candidates, detail-oriented by training) will notice and hold it against you.
2. **Mobile inherits desktop's structure without desktop's density.** Elements that sit comfortably inline on a wide screen (three trust checkmarks, a four-column stat row) get stacked vertically on mobile, multiplying scroll length without multiplying information. For a mobile-majority Indian student audience, this is where signups are actually won or lost, and it's currently working against you.
3. **The site has zero human proof.** Stats say 162 students and 3 experts; nowhere does a student or educator say anything in their own words. This is the single highest-ceiling opportunity on the site, and it's a content-collection problem, not a design problem — you can't fix it by moving a button, but it will outperform every button-color fix in this document once it exists.

Everything else in this document is detail work in service of those three patterns.

---

## 2. First Impression Audit (5-Second Test)

**Test:** if a first-time visitor saw only the fold, could they answer "what is this, who's it for, why should I care, what do I do next" in 5 seconds?

**Landing, desktop — fold contents:** badge ("AI Trusted by 162 Students & 3 Experts"), "RevisOp" wordmark, "The Revision Operating System.", one sentence of value prop, 3 trust checkmarks, "Start free" CTA, "Already a student? Log in", a live flashcard demo card, and the 4-stat row — all of this is genuinely above or right at the fold on a standard 1280×800 viewport.

- **What / Who / Why is clear:** revision tool, spaced repetition, exam-focused, has real content already. Pass.
- **What do I do next is clear:** one dominant "Start free" button. Pass.
- **What's NOT clear in 5 seconds:** whether this is for *any* exam or specifically CA/CMA/CS-type professional exams — the demo card's example question ("damages... under the court") signals commerce/law content, but nothing in the hero copy says "professional exam" or names a category. A visitor outside that niche won't self-select in or out quickly. This is probably intentional (you've said internally RevisOp is course-agnostic, not CA-specific) but the *visitor* doesn't know that — the demo card alone currently reads as "this is a commerce-law flashcard tool," which undersells the course-agnostic positioning. **Medium severity** — consider rotating the demo card through 2-3 different subjects, or adding a one-line "any exam, any subject" qualifier near it.

**Landing, mobile — fold contents:** same content, but stacked. Because the 3 checkmarks go vertical and the paragraph wraps to more lines, the "Start free" button is pushed materially further down than on desktop — my estimate is it's borderline fold/sub-fold on a typical 375×812 viewport, and the stats row and demo card are almost certainly below the fold. **High severity**, detailed in §8.

---

## 3. Conversion Funnel Audit

Three parallel funnels run through these 11 pages:

**A. Student self-serve funnel** (the primary one):
Discovery (homepage, or a shared Note/Deck/Group link) → Interest (hero + demo card, or the gated preview page) → Desire (How It Works / Science-of-memory / Existing Library sections build the "this actually works" case) → Action (Start free → Signup form) → Activation (out of scope here, but the course-selection field on signup implies downstream segmentation, which is good practice).

- **Drop-off risk, Interest→Desire:** the homepage is 17 distinct content bands top to bottom (counted in §5). A lower-intent visitor who doesn't convert off the hero has to pass through a lot of page before reaching the second CTA. Mitigated by the fact that the hero *already has* a CTA, but worth knowing the page is long.
- **Drop-off risk, Action:** mobile CTA position (§8).

**B. Viral/shared-content funnel** (Note/Deck/Group previews):
This is the best-built funnel on the site. A visitor lands on someone else's shared content, sees a real (if partial/gated) taste of it, and gets a clean "sign up free to see the rest" ask with a low-friction "already have an account? sign in" escape hatch. This pattern is executed identically across all three preview types — genuinely good consistency, called out again in §9.
- **Open question I can't verify from screenshots:** does a new signup that arrives via a shared link land back on that specific content post-signup, or does it drop them at a generic dashboard? If it's the latter, you're losing the exact motivation that got them to sign up in the first place. Worth confirming in the actual app.

**C. B2B/institute funnel:**
Discovery (nav "For Institutes," or the landing page's bottom "For Institutes & Educators" section) → Institutes page → Inquiry form → (presumably) manual sales follow-up.
- **Drop-off risk — compounding:** the inquiry form is 7 fields (high for a first-touch B2B form; 3-4 is more typical for top-of-funnel) *and* its submit button renders in a washed-out, disabled-looking color (§4, §10). A motivated institute admin who gets through a 7-field form only to be unsure whether the button even works is a plausible, avoidable drop-off point.

---

## 4. Heuristic Evaluation (Nielsen Norman, 0–4 severity)

*0 = not a problem · 1 = cosmetic · 2 = minor · 3 = major · 4 = usability catastrophe*

| # | Heuristic | Severity | Note |
|---|---|---|---|
| 1 | Visibility of system status | 2 | Institutes page CTA color accidentally communicates "this form isn't active" when it is. |
| 2 | Match between system & real world | 0 | Exam/study language matches the audience's mental model well. |
| 3 | User control & freedom | 1 | Most pages have a clear "back to home" — Student Guide's category jump doesn't visibly offer one. |
| 4 | **Consistency & standards** | **3** | The site's weakest heuristic. Button colors, CTA copy (3 different labels for one action), password-field eye-icon present on Login but not Signup, icon-container shape drifting between adjacent sections (circle vs. square), and nav-label-vs-destination mismatch all land here. |
| 5 | Error prevention | 1 | Signup proactively shows "Minimum 6 characters" — good practice. No form-validation error states were captured, so this can't be fully assessed either way. |
| 6 | **Recognition rather than recall** | **3** | "For Educators" vs. "For Institutes" in the nav requires the visitor to guess/remember which does what rather than recognize it from the label — direct hit on this heuristic. |
| 7 | Flexibility & efficiency of use | 0 | N/A mostly for marketing pages; share-preview pages are efficient for both new and returning users. |
| 8 | Aesthetic & minimalist design | 2 | 17 content bands on one landing page works against the "calm, focused" brand promise stated in your own brief — named as a real tension in §5, not just a nitpick. |
| 9 | Help recognize/diagnose/recover from errors | — | Untested — no error states were captured. Not scored; flag for a follow-up pass once error states can be screenshotted. |
| 10 | **Help & documentation** | **0 (positive outlier)** | The Student Guide is genuinely well-built — organized by user *situation* ("I'm behind on my reviews," "I just signed up") rather than by feature. This is the single best piece of IA thinking on the public site; the rest of the site should borrow its scenario-based framing where relevant. |

---

## 5. Homepage Section-by-Section Critique

The desktop landing page is, top to bottom, **17 distinct content bands**:

1. Top nav
2. Hero (badge, wordmark, subhead, paragraph, checkmarks, CTA)
3. Live flashcard demo card
4. Stat row (162 / 3 / 2183 / 128)
5. "Get your institute on RevisOp" micro-callout
6. Featured Study Sets
7. How RevisOp Works (4 steps)
8. Built on the Science of Permanent Memory (3 feature cards)
9. Start with Our Existing Study Library (second stat block)
10. For Institutes & Educators (2 dark cards + CTA)
11. Ready to Never Forget Again? (final CTA)
12. "Browse the Student Guide" banner
13. Footer

That's not 17 sections of new information — several cover overlapping ground (see below), which is the real issue, not the raw count.

**Section-by-section:**

- **Nav + Hero wordmark redundancy.** The "RevisOp" wordmark appears **twice** within roughly the first 150px of vertical space — once in the nav (small, left-aligned) and once again as a large hero lockup directly below it. On a page fighting for above-the-fold real estate, spending it on the same logo twice is a specific, fixable waste. **Fix:** the nav logo can stay small/functional; the hero doesn't need to repeat the full wordmark treatment — let the hero open directly on "The Revision Operating System."
- **Badge:** "AI Trusted by 162 Students & 3 Experts" — verify whether "AI" is literal text or a mis-rendered icon glyph. If literal, it's an unsupported claim (nothing else on the site mentions AI) and should be removed; if it's an icon, fine, but check how it renders across browsers.
- **Hero paragraph:** "Expert-curated content, your own notes, and peer study sets — all reviewed with spaced repetition so nothing is forgotten before exam day." — "reviewed with spaced repetition" is imprecise; spaced repetition *schedules* review, it doesn't itself "review" content. Minor but fixable precision issue (full rewrite in §6).
- **Demo card:** genuinely one of the best elements on the page — showing a real question instead of a mockup builds credibility no stat can. Keep, and consider rotating subjects (see §2).
- **Stat row #1 (hero):** 162 active students / 3 expert educators / 2,183 flashcards / 128 notes.
- **Featured Study Sets:** shows **exactly one card** in a section titled plural. Visually, there's dead whitespace where more cards clearly belong — this reads as an empty state, not a curated selection. **High severity, easy fix:** either populate with 3+ real cards or rename the section to singular and reframe as "This week's featured set."
- **How RevisOp Works:** clean 4-step structure (Start Reviewing → Upload Notes → Create Flashcards → Never Forget Again), each with its own colored circular icon. Ends in its own CTA ("Start Reviewing Now") — third distinct CTA label for the same action as "Start free."
- **Built on the Science of Permanent Memory:** 3 feature cards (SM-2 / Upload & Digitize / Create Unlimited Flashcards) using **square** icon containers, versus the **circular** containers used one section above in "How RevisOp Works." This is exactly the kind of small drift a Stripe/Linear-caliber design system doesn't allow — pick one icon-container shape and use it everywhere.
  - **Content overlap:** this section and "How RevisOp Works" both explain the mechanism (upload notes → make flashcards → get scheduled review) — once as a 4-step story, once as a 3-card feature list. A visitor gets the same information twice in two different visual formats back to back. **Recommend merging these two sections** — this is the single best opportunity to shorten the page without losing content.
- **Start with Our Existing Study Library:** second stat block — 3 educators / **693** flashcards / **107** notes — directly contradicting the hero's 2,183/128. This is the most damaging single inconsistency on the site (full treatment in §9).
- **For Institutes & Educators (dark section):** best copy on the page ("Bring your institute onto RevisOp. Auto-enroll your batch. Curate content once — every student benefits." — three short, punchy, subject-verb-object sentences). CTA button ("Get My Institute on RevisOp") renders in a muted lavender-grey that doesn't match the navy CTA used everywhere else — looks disabled. **High severity** (detailed in §10).
- **Ready to Never Forget Again? (final CTA):** two equal-weight outline buttons, "Start free" and "Contact Us," side by side. For a student-first product this should not be a 50/50 choice — "Start free" should visually dominate; "Contact Us" (relevant to a small fraction of visitors) should be a secondary/ghost style. The copy above it even says "Start free today" as a singular ask — the UI should agree with its own copy.
- **"Browse the Student Guide" banner + Footer:** no issues; standard, functional, appropriately de-emphasized.

---

## 6. Copywriting Audit

| Location | Current | Note / Rewrite |
|---|---|---|
| Hero paragraph | "Expert-curated content, your own notes, and peer study sets — all reviewed with spaced repetition so nothing is forgotten before exam day." | Imprecise verb. → *"Curated flashcards, your own notes, and study sets from peers — all scheduled by spaced repetition so nothing slips through before exam day."* |
| Badge | "AI Trusted by 162 Students & 3 Experts" | Verify "AI" isn't a stray literal string; if literal, remove — unsupported/off-brand claim. |
| "Built on the Science of Permanent Memory" subhead | "Every feature is designed around one goal: make sure you remember on exam day, not just today." | Slightly wordy. → *"Every feature exists to make sure you remember on exam day — not just today."* |
| "Start with Our Existing Study Library" subhead | "Even before your institute joins, there are already 693 educator-verified flashcards and 107 notes available to browse. Sign up free and start reviewing today." | Buries the value up front, CTA trails after two clauses. → *"693 educator-verified flashcards and 107 notes are already live — browse free, no institute required."* (Also: fix the number conflict with the hero stat first — see §9.) |
| "For Institutes & Educators" subhead | "Bring your institute onto RevisOp. Auto-enroll your batch. Curate content once — every student benefits." | **This is the best copy on the page.** Three short declarative sentences, no filler. Use this cadence as the template for every other subhead on the site. |
| Final CTA subhead | "Join 162 students already using spaced repetition • Start free today." | Fine as-is, but see the CTA-hierarchy mismatch in §5 — align the button design with this copy's singular ask. |
| Institutes page H1 | "Bring Your Institute onto RevisOp" | This is the page's only heading, but the page *also* contains an educator-application section below it that an institute-focused H1 doesn't signal. An individual educator scanning the H1 may bounce before finding their section. See §10 for the structural fix. |

---

## 7. Visual Hierarchy Audit

(Qualitative — see methodology note; no devtools access, so treat spacing comments as estimates.)

- **Color hierarchy is mostly disciplined** — navy is consistently the primary-action color (Start free, Sign Up, Sign In, Send Reset Link) — with one conspicuous, high-visibility exception: the Institutes page CTAs, which is exactly why that break stands out so much (§10).
- **Card design isn't yet a single reusable component.** The hero's demo flashcard card, the Featured Study Set card, and the "Existing Study Library" stat card all appear to use slightly different shadow/border treatments from each other — the demo card reads heavier/more elevated than the flatter Featured Study Set card. Recommend a single card spec (radius, shadow, padding) applied everywhere a "card" appears.
- **Icon-container shape drifts** between adjacent sections — circular icon badges in "How RevisOp Works," square icon badges in "Built on the Science of Permanent Memory," directly below it. Pick one.
- **Section-band alternation (cream/white/navy) works well for the first 3–4 sections** as a wayfinding device, then stops adding value and starts feeling like a slide deck as the page keeps going — ties back to the "merge overlapping sections" recommendation in §5.
- **Accessibility-adjacent finding:** the Institutes page's muted lavender CTA button is a double problem — it *looks* disabled (conversion issue, §4/§10) and its lower contrast against white label text is worth an explicit WCAG contrast check, since it's likely borderline-to-failing where the navy CTA elsewhere clearly passes. Orange link text (Sign in / Log in links) on white/cream backgrounds should also get a contrast check — can't confirm pass/fail from a screenshot alone, but it's close enough to the AA threshold to be worth verifying with a tool.

---

## 8. Mobile UX Audit (390px)

- **Landing hero, High severity:** on desktop, the 3 trust checkmarks ("Free to get started · SM-2 spaced repetition · 2,311+ flashcards & notes") sit in a single inline row. On mobile they stack into 3 separate lines. Combined with the paragraph wrapping to more lines at narrow width, this pushes "Start free" meaningfully further down the page than its desktop position — my estimate is it sits at or just past the typical mobile fold, with the demo card and stat row almost certainly below it entirely. **Fix:** collapse the checkmarks into one line with a separator ("Free to get started · SM-2 spaced repetition · 2,311+ cards"), and reconsider whether the top badge needs to sit above the CTA at all on mobile.
- **Institutes page, mobile:** confirms the same washed-out button color seen on desktop — not a one-off render glitch, it's consistent cross-device, which actually makes it easier to fix (one CSS variable, presumably).
- **Stat row at 390px:** 4 columns (162/3/2183/128) fit without visibly wrapping in the screenshot, but the type is small and the columns are tight — worth a manual finger-test to confirm nothing feels cramped on an actual device, since a screenshot can hide subtle line-height/tap-target issues.
- **Share-preview pages (Note/Study Set/Group), mobile:** hold up well — clean stacking, CTA clearly visible without excess scroll, no overflow. **No issues** — these are the best-performing pages on mobile and a good reference for what "mobile done right" looks like on this site.
- **Student Guide, mobile:** the category list appears to become a horizontal pill/tab row at the top rather than a sidebar — a reasonable mobile pattern, though tap-target size/scrollability can't be fully confirmed from a static screenshot.
- **General tap-target note:** several microcopy links ("Already a student? Log in," "Don't see your course? Select…") look visually small in the mobile captures. Can't measure exact hit-area from an image, but worth a manual pass with a real thumb, not just a mouse cursor.

---

## 9. Trust & Credibility Audit

**The top finding, restated with full weight:** the landing page's own stats contradict each other. Hero: **2,183 flashcards / 128 notes**. Two sections later, same page: **693 flashcards / 107 notes**. There's no label distinguishing "all-time total" from "public library available before signup" or any other explanation — a visitor who notices (and this audience, largely accountants-in-training, notices numbers) now has reason to doubt every other number on the page, including the "162 active students" claim that's doing a lot of social-proof work. **This is the single most damaging trust issue on the site and the cheapest to fix** — reconcile the numbers, or explicitly label what each one measures.

**The biggest missed opportunity:** zero testimonials, quotes, or named human proof anywhere across all 22 screenshots. 162 real students and 3 real, presumably-willing-to-be-quoted educators exist — even 2-3 short text quotes ("cleared my CA Inter first attempt using this" style, with a first name and exam) would out-perform another stat block, because stats can be gamed in a visitor's mind but a specific human quote is harder to dismiss. This is a content-collection task, not a design task, but it belongs at the top of the roadmap (§13) because nothing else in this document has a comparably high ceiling.

**Positive trust signals already in place, worth protecting:**
- The live flashcard demo card (real content beats claims).
- Specific, non-round numbers (2,183; 693; 107) — when consistent, specificity itself reads as authentic in a way "2,000+" wouldn's.
- The Privacy Policy's "Privacy at a Glance" summary box (4 icons: Data Security / No Selling / Limited Collection / Your Control) — this is a genuinely good trust pattern that's currently buried in a legal document almost nobody reads pre-signup. **Recommend surfacing a condensed version of this** (even just "We never sell your data" as a single line) somewhere on the landing page itself, where it can actually do conversion work.
- The "Verified Educator Badge... personally vetted, no self-serve upgrades" language on the Institutes page is a strong quality signal, but it's on a page most student visitors never see. Consider surfacing "every study set is reviewed by a verified educator" (or similar) on the main landing page directly — this also happens to be your sharpest available counter-positioning against Quizlet (§11).

**Strategic tension worth naming, not just listing as a tactic:** the brand brief calls for "calm, focused, trustworthy," but the landing page's instinct to *prove* itself (17 content bands, two separate stat blocks, multiple feature explanations) works somewhat against "calm." Comprehensive proof and calm minimalism pull in different directions — the fix isn't to remove proof, it's to say fewer things more confidently (one stat block, not two; one mechanism explanation, not two) so the page feels as calm as the brand wants to be.

---

## 10. Navigation & Information Architecture

- **Confirmed, and worse than it first appears:** the nav's "For Educators" anchor-scrolls to a landing-page section titled "For Institutes & Educators" whose actual content ("What You Get," batch/CSV messaging, "Why Institutes Choose RevisOp") is **100% institute-focused** — there is no individual-educator content in that section at all. The real "Apply to Teach" form only exists on the separate `/educators` page. So the nav link's label promises educator content and delivers institute content — this isn't just an ambiguous-styling problem (two links that look alike), it's a **label-doesn't-match-destination** problem, which is a step worse. **Fix:** either put real educator-specific content in that landing-page section with a link through to Apply-to-Teach, or rename the anchor to something honest like "Institutes," and let "For Institutes" alone own that word.
- **Top nav is 7 items** on desktop (Features, How it Works, For Educators, For Institutes, Login, Start free, Student Guide) — heavy for a single-scroll landing page where two of those items (Features, How it Works) are anchors to sections on the same page you're already on. Recommend trimming to something like: How it Works · For Institutes & Educators · Login · Start free, with Student Guide moved to the footer or given clearly secondary (non-button) styling so it stops competing visually with "Start free" in the highest-value real estate on the page.
- **Institutes page (`/educators`) tries to serve two personas on one URL** — an institute administrator and an individual educator applicant are different people with different intents, yet both have to scroll past the other's entire pitch to find their own form. The page's own H1 ("Bring Your Institute onto RevisOp") only speaks to one of them. **Recommend** either a tab/toggle at the top of the page ("I run an institute" / "I'm an individual educator") or splitting into two routes with a one-line chooser, so each visitor sees only their own path immediately.
- **Student Guide has no visible "Sign up" path in its own header** — only "Log in." This page is a plausible organic-search landing spot (people search things like "how does spaced repetition scoring work"), and a non-student arriving there has no obvious nav-level path to convert; they have to scroll to a bottom banner or guess that "Log in →" also covers signup. Minor but real, and cheap to fix (add a Sign Up link/button next to Log In).
- **What's working — don't touch it:** the Note/Study Set/Group preview pages consistently pair "Sign up free" with "Already on RevisOp? Sign in" and a tertiary "New to RevisOp? See how X work →" link. This three-tier pattern (primary action / returning-user escape hatch / curiosity link) is textbook-correct and identically executed across all three preview types. If you build more share-gated content types in the future, copy this pattern exactly.

---

## 11. Competitive Positioning (messaging, not features)

RevisOp's real competitive wedge — based on what's actually on these pages — is **"curated content quality + true SM-2 scheduling + zero setup + a social/institute layer."** The site currently states the zero-setup/SM-2 part reasonably well, but doesn't yet explicitly attack the two objections a switching visitor is most likely to be silently holding:

- **"I could just use Anki."** Anki is free, powerful, and true SM-2 — but it has a real setup/UX tax that scares off exactly the audience RevisOp wants (busy exam candidates who've heard of Anki but never opened it because it looks intimidating). RevisOp should say this out loud, not just imply it via "zero setup" language. A short "Coming from Anki? Same science, none of the setup" line or FAQ entry would capture high-intent switchers cheaply — right now that objection just goes unaddressed and the visitor has to infer the answer themselves.
- **"I could just use Quizlet."** Quizlet's actual weakness is content quality — mass, crowdsourced, uneven, ad-supported, and its scheduling isn't true spaced repetition. RevisOp's "Verified Educator Badge" and "personally vetted, no self-serve upgrades" language directly counters this — but it's currently buried on the Institutes page where most students never see it. **Say it on the landing page, explicitly:** "Every study set is reviewed by a verified educator — not crowdsourced guesswork" is a one-line, high-leverage counter-positioning statement that costs nothing to add.
- **RemNote** positions itself as a "second brain" / knowledge-management tool for university and lifelong learners — more abstract, less exam-outcome-focused. RevisOp's outcome-first language ("Ace Every Exam," "exam day," presumably rank/score framing elsewhere in-app) is already differentiated from this; keep leaning into concrete exam-outcome language rather than drifting toward "knowledge management" vocabulary.
- **Notion** isn't a direct competitor but is a real informal substitute for note-taking among this audience. Its structural weakness for revision specifically is that it has *no* review-scheduling — a Notion user has to remember to revisit their own notes. RevisOp's "Upload & Digitize Notes" (photo → OCR → flashcard queue) is a sharp, specific hook for exactly this Notion-refugee, and it's currently under-sold as one bullet among several rather than a headline feature. Consider a dedicated, named callout: "Already have notes somewhere else? One photo turns them into a review queue."

**Recommendation:** a short, explicit 3-column "why not just use Anki / Quizlet / a notebook" comparison block (common on SaaS landing pages for exactly this reason — pre-empting the objection before the visitor has to ask it) would likely outperform another generic feature-benefit section, because it directly answers the question a switching visitor is actually asking.

---

## 12. Quick Wins (< 1 day of work)

Mostly CSS/copy — no new components required.

1. Reconcile the two conflicting stat blocks (2,183/128 vs. 693/107), or explicitly label what each measures.
2. Fix the Institutes page CTA button color to match the site's real primary-button navy — currently the highest-impact single fix on the site relative to effort.
3. Rebalance the final landing CTA section — make "Start free" the solid/dominant button, demote "Contact Us" to secondary/ghost styling.
4. Standardize on one CTA label for the signup action across the whole page ("Start free" — drop "Start Reviewing Now").
5. Add the password show/hide eye icon to Signup to match Login (currently only on Login).
6. Verify/fix the hero badge's "AI" text or icon rendering.
7. Reduce the redundant double-wordmark in the hero (nav logo + hero logo within ~150px).
8. Unify icon-container shape (circle vs. square) between "How RevisOp Works" and "Built on the Science of Permanent Memory."
9. Add a "Sign up" link next to "Log in" in the Student Guide's header.
10. Surface one line from the Privacy Policy's "Privacy at a Glance" box (e.g. "We never sell your data") onto the landing page.

## 13. Medium-Effort Improvements (1–2 weeks)

1. **Restructure the Institutes page** into a persona chooser (institute admin vs. individual educator) so each visitor sees only their own path immediately; trim the institute inquiry form from 7 fields down to 3-4 for the first touch.
2. **Compress the mobile hero** — inline the checkmarks, tighten the paragraph, re-test where "Start free" lands relative to the fold on real devices.
3. **Fix the "For Educators" nav destination** — either add real educator-specific content to the anchor section, or repoint the link to the actual Apply-to-Teach form.
4. **Trim the top nav** to 5 items or fewer; move Student Guide out of button-styled competition with "Start free."
5. **Add an explicit competitive-objection block** ("why not Anki/Quizlet/a notebook") per §11.
6. **Fix Featured Study Sets** — populate with a real multi-card row, or rename to singular framing.
7. **Merge "How RevisOp Works" and "Built on the Science of Permanent Memory"** into one section — same mechanism, currently explained twice (§5).

## 14. Strategic Improvements (roadmap, beyond a sprint)

1. **Collect and publish 3-5 real student/educator testimonials** (text or short video), with names/exams where permission allows. Single highest-ceiling investment in this entire audit — outranks every tactical fix above on impact, which is why it's listed here rather than as a "quick win": it requires outreach and content collection, not just an edit.
2. **Build a lightweight component spec** (button variants, card spec, icon-container shape) so future pages don't drift from brand the way the Institutes page and icon shapes already have. This prevents the "Consistency & Standards" heuristic failure (§4) from recurring as the site grows past 11 pages.
3. **Shorten the landing page narrative deliberately** — not just merging two sections (§13), but deciding which of the remaining bands are load-bearing for conversion vs. which exist because they seemed reasonable in isolation. A "calm, focused" brand promise is easier to keep on a shorter page.
4. **Stand up basic A/B testing infrastructure** so the five test ideas below get validated by data rather than shipped by opinion.

## 15. Likely A/B Tests Worth Running

1. Single-line vs. current stacked checkmarks on mobile hero → measure scroll-depth-to-CTA-click.
2. One consistent CTA label ("Start free") site-wide vs. current mixed labels → measure aggregate signup click-through.
3. Institutes page as a single-persona landing (with educator application on its own route) vs. current combined page → measure form-start rate per persona.
4. One reconciled stat block shown once vs. current two-stat repetition → measure trust-signal recall / bounce rate.
5. A testimonial strip directly under the hero stats vs. no testimonial (current) → measure signup conversion lift. This is the test most likely to move the needle the most, once testimonial content exists to test.

---

## 16. Priority Matrix (Impact × Effort)

| Impact ↓ / Effort → | Low | Medium | High |
|---|---|---|---|
| **High** | Fix stat mismatch · Mark optional fields consistently on Institutes forms · Rebalance final CTA · Compress mobile hero (checkmarks: drop `flex-col`/keep `sm:flex-row` at all widths) | Restructure Institutes page persona split · Fix "For Educators" nav destination · Merge overlapping mechanism sections | Collect & publish testimonials |
| **Medium** | Standardize CTA label · Add Signup password toggle (share Login's component) · Reduce hero wordmark redundancy | Trim nav to 5 items · Add competitive-objection block · Fix Featured Study Sets · Unify auth-form components (Login uses shadcn inputs, Signup uses custom Tailwind) | Component spec / design system |
| **Low** | Unify icon-container shape (9999px vs 12px radius) | Surface Privacy-Policy trust line on landing | Deliberate landing-page-length reduction (strategic narrative pass) |

**Read this matrix top-left-to-bottom-right for sequencing:** everything in the top-left cell should ship this week; everything in the bottom-right is a deliberate, planned initiative, not a punch-list item.

---

*End of audit. This document reviews the public/logged-out surface only, per the "Section 1" scope in the screenshot checklist. The logged-in student/professor/admin experience (Sections 2–4 of that checklist) is a separate review with a different job — task efficiency and cross-page consistency for committed users, not conversion.*

---

## 17. Live Verification Addendum (05/07/2026)

Everything below was checked directly against the live site (revisop.com) via computed styles and DOM inspection, not re-estimated from screenshots. One finding above was **corrected** — flagged clearly. Everything else was **confirmed** with concrete evidence.

### Correction: the Institutes page CTA color is not the problem

Live inspection shows both submit buttons (`Get My Institute on RevisOp`, `Submit Application`) use the correct brand navy (`rgb(30, 27, 75)`) at full opacity **once the form is valid**. On page load, both buttons are `disabled: true` at `opacity: 0.5` — a disabled-until-valid submit pattern, not a wrong brand color. Filling the required fields flips them to `opacity: 1`, same navy as everywhere else. The screenshot-based finding correctly identified the symptom (looks broken/disabled) but misdiagnosed the cause (thought it was a color/branding bug — it's a form-state bug).

**The real, more specific problem, verified live:**
- Institute form's actual required fields are just **Institute Name, Contact Name, WhatsApp Number** (3 of 7) — City, Email, Course, and Message are all optional. The 7-field visual weight is misleading; the real friction is lower than it looks.
- Educator application form's actual required fields are **Full Name, WhatsApp Number, Credential/LinkedIn URL** (3 of 7) — Email, Institute, Course, and "Why do you want to teach" are optional.
- **But there is no visible marker distinguishing required from optional fields**, except that exactly one field ("Message (optional)") is explicitly labeled — every other optional field (City, Email, Course on the institute form; Email, Institute, Course, Why on the educator form) looks identical to the required ones. A visitor has no way to tell which 3 fields they actually need to fill, and the disabled button gives **no tooltip, aria-label, or inline message** explaining what's missing — it just silently won't click.
- **Revised fix:** either mark every optional field consistently (add "(optional)" to all four, not just Message), or drop the disabled-until-valid pattern entirely and let the button stay clickable with inline validation errors shown on a failed submit attempt — the latter is generally the better-tested UX pattern (Nielsen heuristic #9: help users recognize and recover from errors, which a silently-disabled button doesn't do).

### Confirmed with concrete evidence

- **Stat mismatch is live right now, not a stale screenshot artifact.** Hero row: `2183 Flashcards`, `128 Notes`. "Start with Our Existing Study Library" section, same page: `693 Flashcards`, `107 Notes`. Verified via direct text extraction from the current production DOM.
- **Badge text has no literal "AI" string** — live text is exactly `"Trusted by 162 Students & 3 Experts"`. The "AI" read in the screenshot was very likely a small icon glyph rendering oddly at screenshot resolution, not copy. **This item is resolved — no action needed**, retracted from the punch list above.
- **Final-CTA hierarchy confirmed at the pixel level:** `Start free` (solid) and `Contact Us` (outline) in the "Ready to Never Forget Again?" section are both `64px` tall, both `font-weight: 600`, both `padding: 16px 32px`, widths differing only by their text length (140px vs 157px). They are, by every measurable property, the same visual weight — one filled white, one 2px white outline. Confirms the original finding precisely.
- **Icon-container shape drift confirmed via computed `border-radius`:** "How RevisOp Works" icon badges are `border-radius: 9999px` (true circles); "Built on the Science of Permanent Memory" icon badges one section below are `border-radius: 12px` (rounded squares). Same page, adjacent sections, two different container shapes.
- **Password show/hide toggle inconsistency confirmed, with a deeper root cause than "missing icon":** Login's password input carries shadcn/ui classes (`flex h-9 rounded-md border-input...`) and is immediately followed by a `<button type="button">` toggle. Signup's password input carries entirely different, hand-written Tailwind classes (`w-full px-4 py-3 border-gray-300 rounded-lg...`) with no toggle button at all. These two pages aren't using the same form-input component — that's the actual bug, and it likely causes other small drifts (border-radius, focus-ring color: `amber` on Signup vs. the default `ring` token on Login) beyond just the missing icon. **Recommend componentizing the auth forms** rather than patching the icon in isolation.
- **Note-preview blur confirmed as decorative, not real content:** the blurred container (`filter: blur(4px)`) has zero text content and 8 empty grey `<div>` children — it's a skeleton placeholder with blur applied for effect, not an actual blurred rendering of the gated note text. Matches the original screenshot-based read exactly.
- **Mobile checkmark stacking confirmed via source, not an estimate:** the trust-checkmark row's class list is literally `flex flex-col sm:flex-row ... space-y-4 sm:space-y-0`. Below Tailwind's `sm` breakpoint (640px) — which covers every phone, including 390px — this row is vertically stacked with a 16px gap between each line. This is a direct, unambiguous confirmation of the mobile-hero-bloat finding in §8, straight from the shipped class names.

### Not re-verified this pass

Student Guide, Forgot Password, Terms of Service, Privacy Policy, and the Study Set/Group-join preview pages were not re-inspected live — the original screenshot-based findings for those pages didn't hinge on anything a static image couldn't show reliably (copy, layout, presence/absence of elements), unlike the color/state/class-level questions above.

---
Section B Logged in Pages Review
## Section 1 — Dashboard + Study Flow

**Pages covered:** 12-dashboard, 14-study-mode (question/answer), 16-review-session (subjects/question/answer), 15-review-flashcards, 17-review-by-subject — desktop + mobile.

One data gap up front: **17-student-review-by-subject** (both widths) shows the "All Caught Up" empty state, not a populated subject list. I can evaluate the empty state itself but can't assess this page's normal hierarchy/density — flagging rather than guessing at what's missing.

---

**1. [12-dashboard, both widths] MED — Primary actions are split across the top and bottom of a long page.** The "All caught up!" banner at the top offers Browse Study Sets / Browse Notes; ~10 card-sections later, "Quick Actions" offers Browse Notes / Browse Flashcards / Upload Note / Create Flashcard — overlapping intent, but you have to scroll past streaks, accuracy, "You vs Class," Class Milestones, Leaderboard, and Recent Activity to reach it. **Why it matters:** for a returning, committed user (this section's actual audience), core creation actions shouldn't be buried under social/stat cards. **Fix:** move Quick Actions directly under the welcome banner; drop the redundant Browse-Notes/Sets pairing in the top banner once it exists below.

**2. [12-dashboard, both widths] LOW-MED — Two large near-empty cards back to back.** "You vs Class" ("Comparison stats will appear when more classmates join") and "Recent Activity" ("No new content in the past week") both render at full card height despite having nothing to show. **Why it matters:** for exactly the small/early cohort you have right now, two full-size empty cards in a row reads as "not much happening here" to the users you most need to retain. **Fix:** give empty states a slim single-line treatment instead of a full card frame. (Noting this as an option, not a directive — you already have a rule against silently hiding settled dashboard cards behind a conditional; this is about sizing the empty state, not hiding it.)

**3. [14-study-mode vs 16-review-session, both widths] MED-HIGH — Two flows, near-identical UI, unclear if they mean the same thing to your SRS scheduler.** Both show the exact same question/answer card, same Easy/Medium/Hard rating, same Skip/Report controls. But Study Mode's counter reads "Card 1 of **696**" (looks like your whole pool) while Review Session's reads "Card 1 of **7**" scoped to one due subject, and only Review Session carries a "Reviewing: 7 cards due" banner — Study Mode has no equivalent marker. **Why it matters:** in a spaced-repetition app, whether a card you just rated "Easy" was actually due (and thus meaningfully reschedules) or just free practice matters a lot, and there's almost no persistent cue mid-session telling you which one you're in. **Fix:** carry a visible session-type badge on the card itself (not just the entry banner) through the whole flow, and label Study Mode's counter as "696 available" vs. Review Session's "due today" so the distinction never disappears.

**4. [12 vs 14/16, both widths] HIGH — Active-nav highlighting works on one page and silently drops on two others.** "Dashboard" gets a highlighted pill in the top nav on the Dashboard page; neither Study Mode nor Review Session highlights "Study," even though you're clearly inside that section. **Why it matters:** this is exactly the class of drift this review exists to catch — a basic "where am I" cue that isn't applied consistently across the same nav bar. **Fix:** apply the same active-state pill to whichever top-level item matches the current section, on every page.

**5. [16-review-session, both widths] LOW — Nav item count differs from the other student captures.** This capture's top nav has 5 items (adds "Analytics") plus a course-switcher pill ("CA Intermediate ▾") that aren't present on 12/14's nav, despite the checklist labeling all of these "student" role. **Why it matters:** I can't tell from screenshots whether this is a real per-student feature missing from the other captures, or two different test accounts got mixed into the "student" set — worth a quick manual check either way, since if it's real it should appear everywhere for students, not just here. **Fix:** confirm the account/role that produced this screenshot; if Analytics + course-switching are meant to be universal for students, verify they render on every student page.

**6. [15-review-flashcards, mobile] HIGH — Filter bar and card grid both collapse to full-width stacks, more than doubling scroll length.** Desktop's 5-dropdown filter row and 3-column topic-card grid both become single-column stacks on mobile — page height goes from ~2700px (desktop) to ~5850px (mobile) for identical content. **Why it matters:** browsing 461 cards' worth of topics means a lot of scrolling before reaching anything useful, and this is the same "controls stack and bloat vertical space" pattern already flagged on the public marketing pages — it's now a recurring, site-wide component issue, not a one-off. **Fix:** collapse the 5 filters into a single "Filters" button opening a bottom sheet on mobile; consider a denser 2-up card grid instead of full-width single cards.

**7. [14/16 card screens vs 12/15/17 list screens, both widths] LOW — Background color switches between grey and cream, apparently by screen type — worth confirming it's deliberate.** List/selection screens (Dashboard, Review Flashcards, the subject list) sit on light grey; the actual question/answer card screens (both Study Mode and Review Session) sit on pale cream, matching the public landing page's cream sections. **Why it matters:** if this is an intentional "active-recall focus mode" tint, it's a nice touch worth keeping — but it's the single most visible color variable in the logged-in app, so it should be a documented rule ("card-review screens = cream") rather than something that happened to land consistently by accident. **Fix:** confirm intent; if deliberate, document it so future review-type screens follow the same rule.

---
## Section 2 — Flashcards + Notes

**Pages covered:** 18-my-flashcards, 19-create-flashcard, 20-my-notes, 21-browse-notes, 22-note-detail, 23-note-upload, 24-my-contributions — desktop + mobile.

---

**1. [22-note-detail, both widths] HIGH — Sticky nav bar overlaps the page title on scroll.** On desktop, the note title "SM1 Ch7 Overall Scheme of Valuation (Sec 15)" is visibly clipped behind the white nav strip. On mobile it's worse — the title text and the "CA Anand More · Professor" author badge both render directly underneath the nav bar, badge and text overlapping it. **Why it matters:** this isn't a taste call, it's a broken layout — a fixed/sticky header sitting on top of content it should sit above. **Fix:** add scroll-margin or top-padding to the note-detail content equal to the sticky nav's height, or z-index/stacking order the nav correctly above a spacer.

**2. [22-note-detail, both widths] MED — A note is browsable and clickable, then turns out to be non-functional after the click.** This note (tagged "Mindmap") opens into a "Full access coming soon — leave your WhatsApp number to get notified" lead-capture wall, even for a logged-in student. Nothing in the Browse Notes list this came from signaled that it was a preview/waitlist item rather than real content. **Why it matters:** a committed user clicking into content expecting to study it, and instead hitting a marketing waitlist form, is a jarring task-flow break — worse than just not listing it yet. **Fix:** either mark not-yet-available content types with a visible badge in the list view before the click, or hold them out of Browse Notes entirely until they're real.

**3. [20-my-notes, desktop+mobile] MED — Note thumbnail renders as a blank rectangle with nothing in it.** The one seeded note's preview area is a flat pale-yellow box — no icon, no "preview unavailable" text, nothing. **Why it matters:** this reads as a broken image, not an intentional empty state — compare to Note Upload's dashed box with a clear icon + instructions, which gets this right. **Fix:** add a placeholder icon/pattern to empty thumbnails so it reads as "no preview yet," not "something failed to load."

**4. [21-browse-notes vs 18-my-flashcards/15-review-flashcards] MED — Two "browse content" pages default to different information density.** Browse Notes collapses everything to subject-level summary rows (GST · 60 notes · 59 from professors) that require a click to expand into actual notes. My Flashcards / Review Flashcards show full topic-level preview cards immediately, no extra click. **Why it matters:** these are the same kind of task (find content to study) solved two different ways depending on which content type you're browsing — a returning user has to relearn the pattern per page. **Fix:** pick one default (given Review Flashcards' inline-preview approach already works well and scales via "Preview: first 10 of N," extend that pattern to Browse Notes rather than the reverse).

**5. [Cross-page, refines a Section 1 finding] HIGH — Active-nav highlighting is inconsistent in a specific, now-clear pattern.** Checked across both sections: **Dashboard** (12), **Create Flashcard** (19), **Upload Note** (23), and **Browse Notes** (21) all correctly highlight their top-nav item. **My Flashcards** (18), **My Notes** (20), **My Contributions** (24), **Study Mode** (14), and **Review Session** (16) show no highlight at all. The pattern: pages reached directly from a top-nav click work; "my content" pages and in-progress review/study screens don't. **Why it matters:** this is systematic, not a one-off — roughly half the logged-in app loses its wayfinding cue. **Fix:** the nav's active-state logic needs to match on route prefix (e.g. anything under `/dashboard/flashcards*`, `/dashboard/notes*`, `/dashboard/study*`) rather than only exact top-level routes.

**6. [24-my-contributions vs 12-dashboard, both widths] LOW — "Quick Actions" is duplicated across pages with slightly different labels for the same action.** Dashboard offers "Browse Notes / Browse Flashcards / Upload Note / Create Flashcard"; My Contributions offers "Upload Note / Create Flashcard / View My Notes / View Flashcards" — different verbs (Browse vs View) for what's functionally the same destination-shaped block, repeated on at least two pages. **Why it matters:** small, but it's evidence this block isn't a single shared component with one source of truth for copy — future edits will drift further. **Fix:** componentize "Quick Actions" once, reuse it, and settle on one verb per action.

**Positive, worth calling out:** Create Flashcard (19) and Upload Note (23) both use the *correct* required/optional field pattern — a red asterisk on required fields, an explicit "(Optional)" suffix on optional ones. This is exactly the pattern I flagged as missing on the public Institutes/Educators inquiry form in the earlier audit — worth retrofitting that page to match what these two logged-in forms already do right.

---

## Section 3 — Progress + Social

**Pages covered:** 25-progress, 26-achievements, 27-author-profile, 28-settings, 29-find-friends, 33-my-groups, 34-group-detail, 13-navigation (mobile only) — desktop + mobile except where noted.

One correction to Section 2 first, prompted by seeing the same pattern again here:

**Revision: the "sticky nav overlaps content" bug is likely a screenshot-capture artifact, not a live bug.** Author Profile (27, desktop) shows the exact same overlap I flagged as HIGH severity on Note Detail — the profile name/badge clipped behind the nav bar. But the checklist states these desktop captures use the GoFullPage extension, which has a known quirk: it can mis-composite `position: sticky`/`fixed` headers when stitching a scrolled full-page capture, making a sticky header appear to overlap content that it wouldn't overlap during normal live scrolling. Seeing the identical pattern independently on two unrelated pages (Note Detail, Author Profile) is more consistent with a shared capture-tool artifact than two separate live layout bugs. **Revised recommendation:** before any engineering time goes into this, do a 30-second manual scroll-check on the live site on both pages. If it doesn't reproduce live, it's not a real bug — just don't trust GoFullPage captures for anything with a sticky header going forward.

---

**1. [26-achievements, both widths] MED-HIGH — This page reads as gamified in a way the rest of the product deliberately doesn't.** Trophy header icon, locked-padlock badge cards, "Overall Progress 11%" bar, and copy like "You are a legend" / "You are the heart of the community" / "True dedication to your craft." **Why it matters:** your own brief for this review states the brand direction as "calm, focused, trustworthy — not gamified or childish." Every other page in this set is fairly restrained; this one is the clear outlier, and it's not a spacing/color nitpick — it's a tone mismatch. **Fix:** this is a product call, not a CSS fix — either accept that Achievements is deliberately the one "fun" corner of the app, or tone down the superlative copy and lock/trophy iconography to match the rest of the product's register.

**2. [25-progress, desktop+mobile] MED — "Due Today: 0" is styled as an alarm.** The Due Items Forecast card for "Due Today" uses a red/alert color regardless of the actual count — so 0 due (good news, nothing overdue) still renders in a red warning box. Compare to the Dashboard's "All caught up!" banner, which treats the same underlying state (nothing due) as something to celebrate, not warn about. **Why it matters:** the same real-world state is colored as bad news here and good news there — a real cross-page semantic inconsistency, not just a palette choice. **Fix:** either make the red conditional on the count (red only when >0 and overdue, neutral/green when 0), or drop the red entirely and let the number speak for itself.

**3. [27-author-profile, 29-find-friends, both widths] MED, compounds at scale — "Follow" and "Add Friend" sit side by side with no explanation of what each does, and Find Friends repeats this 30 times on one page.** Neither page explains the functional difference between following someone and friending them (visibility? leaderboard inclusion? mutuality?). **Why it matters:** on a single profile this is a small ambiguity; on the Find Friends directory it's the primary decision a user has to make about 30 different people, unexplained each time. **Fix:** a one-line tooltip or subtext under the two buttons the first time a user sees them ("Follow to see their public content · Add Friend to study together and appear on each other's leaderboard") would resolve this everywhere at once.

**4. [29-find-friends, both widths] MED-HIGH — The small colorful badge-icon clusters next to each name are illegible at this size and unlabeled.** Every row in the 30-person directory shows a cluster of tiny colored circular icons (presumably achievement badges) with no visible label or legend. **Why it matters:** this is the main "personality" signal on the entire directory page, and as shipped it reads as decorative noise rather than information — a user can't actually use it to decide who to add. **Fix:** either add a hover tooltip naming each badge, or drop the icon clusters from the list view and surface them only on the full profile where there's room to label them (as 27 already does, better, with text labels next to each badge).

**5. [29-find-friends, desktop] MED — A 30-person directory renders as one full-width column instead of a grid, on a page with plenty of horizontal room.** Each person's row spans the full 1265px width for what's fundamentally a compact amount of content (name, badges, email, course, two buttons), pushing the page to ~3700px of scroll. Compare to My Flashcards (18) or Review Flashcards (15), which use 3-column grids for similarly-sized content on the same viewport width. **Why it matters:** this is a missed opportunity to reuse a pattern that already exists and works elsewhere in the app — inconsistent grid usage for comparable content types. **Fix:** move to a 2-3 column card grid matching the pattern already established on the flashcard-browsing pages.

**6. [13-navigation, mobile] LOW — Menu grouping is inconsistent within itself.** STUDY, CREATE, and GROUPS get all-caps section headers; My Progress, My Contributions, My Achievements, and Settings are left as an ungrouped flat list directly below, despite being just as groupable (e.g., under "ME" or "ACCOUNT"). **Why it matters:** cheap, cosmetic, but it's the kind of half-finished-looking detail that undercuts "calm and considered." **Fix:** add a fourth section header over those four items.

**7. [13-navigation, mobile] — Worth a manual check, not a design fix.** The student nav menu links to "Bulk Upload" under Create, but no student-facing Bulk Upload page was captured anywhere in this screenshot set (Bulk Upload only appears numbered under the Professor section, #39). Either students genuinely have this feature and it just wasn't screenshotted, or it's a professor-only feature leaking into the student nav. Worth a two-minute click-test rather than guessing.

**8. [13-navigation, mobile] — This resolves an open question from Section 1.** The student mobile nav has no "Analytics" item at all, which confirms my Section 1 flag: the account that captured **16-review-session** (which showed a 5-item nav with Analytics and a course-switcher pill) most likely was not a plain student account. **Recommend:** re-capture #16 with a genuine student account before treating anything about that screenshot's nav as representative.

**Positive, worth calling out:**
- **Group Detail (34)** is one of the cleanest, most consistent pages in the whole review — correct button hierarchy (Invite Members solid/primary, Share Content outline/secondary), logical layout, and WhatsApp-first invite sharing that matches the same WhatsApp-centric pattern already used on the public Institutes page. Good cross-surface consistency, worth treating as a reference page.
- **Author Profile's** badge display (text label + icon per badge) is the *right* way to show badges — compare it to Find Friends' unlabeled icon clusters (#4 above) and use Profile's pattern there instead.

---

## Section 4 — Professor

**Pages covered:** 37-professor-dashboard, 38-professor-analytics, 39-professor-bulk-upload — desktop + mobile.

This section resolves an open question from Sections 1 and 3:

**Confirmed: the "Analytics" nav item + course-switcher pill belong to the Professor role, not Student.** All three Professor pages here show the same 5-item nav (Dashboard, Study, Create, Groups, Analytics) plus a "CA Intermediate ▾" course-switcher pill — matching exactly what appeared in **16-student-review-session** back in Section 1, and matching neither the plain student nav (Dashboard/Study/Create/Groups, no Analytics) nor the student mobile menu (13), which also has no Analytics item. **This confirms #16 was very likely captured with a professor-privileged account, not a plain student account** — worth re-capturing that screenshot before treating its nav as representative of what students actually see.

---

**1. [38-professor-analytics, desktop+mobile] HIGH — The quality-tier color legend describes the wrong tier.** The page reads: *"Amber rows — avg quality below 3 means students are finding these cards hard."* But in the Subject Engagement table, Auditing & Ethics sits at **3.7/5** and is colored **amber** — which is above 3, not below it. Cross-checking the "Challenging Cards" list below (all genuinely <3, e.g. 1.0/5, 1.5/5, 1.7/5) confirms those render in **red**, not amber. So the actual system is Green ≥4 / Amber 3–4 / Red <3, but the caption text describes the red tier's threshold and mislabels it as amber. **Why it matters:** this is the page's entire reason for existing — telling a professor which content is working and which isn't — and the explanatory text next to the data is factually wrong about what the color means. A professor skimming this could misjudge which subjects actually need attention. **Fix:** correct the caption to describe amber's real range (3–4) and either add a visible red-tier callout or drop the "below 3" framing from the amber caption entirely.

**2. [38-professor-analytics, mobile] HIGH — The Subject Engagement table silently drops its two most important columns.** On mobile, the table shows Subject/Cards/Students but the Reviews and Avg Quality columns — the actual analytics the page is for — aren't visible in the captured viewport, and there's no visible scroll shadow/gradient or "swipe for more" affordance hinting that more columns exist off-screen. **Why it matters:** if a professor can't tell there's more to scroll to, they may never see the quality scores at all on their phone — which, combined with finding #1, means the mobile experience of this page's core metric is both hard to find and mislabeled when found. **Fix:** add a visible horizontal-scroll cue (edge shadow or a small "→ scroll" hint) on any table wider than the viewport, here and anywhere else in the app doing the same thing.

**3. [37-professor-dashboard vs 12-student-dashboard, both widths] Neutral observation, not a bug — the two dashboards share a component style but not an information philosophy.** Professor Dashboard is four sections (Your Content, Quick Actions, Needs Attention, Recent Activity) — notably shorter and more task-focused than the Student Dashboard's ten-plus sections (streaks, accuracy, leaderboard, milestones, etc.). **Why it's worth naming rather than just letting it pass:** this is actually the right call — a professor's job on this page is different from a student's — but it means "Dashboard" as a concept looks and behaves quite differently by role, worth being a deliberate documented choice rather than something that happened because the two were built at different times.

**4. [37-professor-dashboard, both widths] LOW — "Needs Attention" has a visibly heavier border than the "Recent Activity" card directly below it,** even though both are currently in a benign/empty state ("No flags... All clear"). **Why it matters:** a heavier border usually signals "look here, something's off" — applying it even to the all-clear state slightly cries wolf. **Fix:** either match its border weight to other cards when there's nothing to flag, or reserve the heavy border specifically for when there *is* something needing attention.

**Positive, worth calling out:** **Bulk Upload (39)** is a genuinely well-built page — a clear numbered 3-step accordion, the active step visually distinct (dark badge + amber border), and helpful inline guidance ("Don't see your subject/topic? Create one via Create Flashcard or Upload Note first, then re-download Valid Entries"). No notes here beyond the open question already flagged in Section 3 about whether this route is meant to be reachable by students at all.

---
## Section 5 — Admin / Super Admin

**Pages covered:** 40-admin-dashboard, 41-admin-analytics, 42-superadmin-dashboard, 43-superadmin-analytics — desktop + mobile.

One transparency note before the findings: **42-superadmin-dashboard is effectively illegible at the resolution provided** — the desktop capture is 1265×15,274px and the mobile one is 375×17,848px, compressed down for viewing to the point where the user-table rows and most stat values can't be read with confidence. I can confirm the page's structure (section headers like "User Growth & Retention," "Content Creation Report," "Study Engagement Report," a long user table) and I can confirm its sheer size, which is itself a finding (below) — but I'm not going to guess at specific numbers I can't actually read, since a misread digit would be worse than no finding at all. If you want a real per-row critique of this page, it'd need a re-capture split into smaller chunks.

---

**1. [40-admin-dashboard vs 41-admin-analytics vs 43-superadmin-analytics, all widths] HIGH — "Total Users" disagrees across three pages, and it's not random noise — it's specifically the Dashboard that's the outlier.** Admin Dashboard's stat card reads **169** ("+4 this week"). Admin Analytics reads **171**. Super Admin Analytics also reads **171** — the two Analytics pages agree with each other; only the Dashboard disagrees. **Why it matters:** this is the exact same "stats contradict each other" pattern already flagged twice on the public marketing site, now confirmed inside the admin tooling too — and this time there's a clean explanation available (Dashboard is very likely reading a stale/cached count while both Analytics pages compute live), which makes it a quick, specific fix rather than a mystery. **Fix:** point the Dashboard card at the same live query the Analytics pages use, or label it with an "as of" timestamp if some caching is intentional.

**2. [41-admin-analytics vs 43-superadmin-analytics, both widths] HIGH — Published-items counts per course disagree between the two Analytics pages themselves.** Admin Analytics' "Content Health by Course" table shows CA Intermediate: **458** published items, CA Foundation: **235**. Super Admin Analytics' "Course Cohort Comparison" table shows CA Intermediate: **544**, CA Foundation: **256** — same metric name, same two courses, two dedicated analytics pages, two different numbers each. **Why it matters:** these are the two pages whose entire purpose is being the authoritative source of truth for platform health — if they disagree with each other, neither can be fully trusted, and this is now the third distinct instance of the same underlying pattern (public landing page stats, Admin Dashboard vs Analytics, and now Analytics vs Analytics). This has stopped being a one-off and is worth treating as a systemic data-pipeline issue, not a copy typo. **Fix:** find the two queries computing "published items per course" and reconcile which one is right — likely one is filtering by a status or date range the other isn't.

**3. [38-professor-analytics + 41-admin-analytics, cross-referenced] HIGH — Confirms and sharpens a Section 4 finding: the quality color-tier boundary is inconsistent, not just mislabeled.** Section 4 flagged Professor Analytics' amber caption as wrong. Here on Admin Analytics, a course with **avg quality exactly 4.0** renders **amber**, even though Professor Analytics' own donut-chart legend defines "Easy" as "**≥4.0**" and colors that tier green. So the boundary itself shifts depending on which page you're looking at, not just the caption text. **Why it matters:** this confirms the quality-tier color system needs one shared definition, not per-page reimplementation — three separate pieces of evidence now (Professor's mislabeled caption, Professor's donut vs Admin's table boundary, and Admin's own 4.0-as-amber) all point at the same root cause. **Fix:** extract the Easy/Medium/Hard color-threshold logic into one shared utility and use it everywhere quality scores are displayed.

**4. [40-admin-dashboard, both widths] MED-HIGH — A note is marked "Currently Live" (featured) in Admin, but the public site's Featured section never showed it.** Admin's "Landing Page Content → Currently Live" table lists both a Deck ("Business Laws — ICA 1872...") and a Note ("Ch7 The Negotiable Instruments Act") as live/featured. But the public landing page audit (done earlier in this conversation) found only **one** Featured Study Sets card and no featured-notes section at all. **Why it matters:** this is a direct, checkable disconnect between what the admin panel believes is published to the public site and what's actually rendering there — worth verifying whether there's simply no public UI slot for featured notes yet, in which case this admin control is currently a no-op. **Fix:** confirm whether the public site has a "Featured Notes" surface; if not, either build one or remove the ability to feature a note from Admin until it does something.

**5. [40-admin-dashboard, both widths] MED — Admin's content-moderation lists (Public Notes, Public Study Sets) have no search or filter, only a "Load more" button — a step down from the equivalent student-facing pages.** Browse Notes and Review Flashcards (student-facing) both have a full filter bar (Course/Subject/Topic/Role/Author). Admin's moderation view of the same underlying content has none of that, just sequential "Load more" pagination. **Why it matters:** the person managing potentially hundreds of pieces of content across a growing platform has a worse filtering tool than the students browsing the same content — this will become a real operational bottleneck well before it becomes one for students. **Fix:** reuse the existing filter-bar component from Browse Notes/Review Flashcards here.

**6. [40-admin-dashboard, mobile] MED — The 7-column "Currently Live" table gets crammed into mobile width rather than reflowing to cards.** Unlike Professor Analytics (Section 4), which drops columns on mobile, this table instead squeezes all 7 columns (Title/Type/Subject/Topic/Owner/Approved By/Approved/Actions) into tiny multi-line cells at mobile width — arguably worse, since everything becomes hard to read rather than cleanly hidden. **Fix:** convert to a stacked card layout on mobile, same pattern as the flashcard/note browsing pages already use.

**7. [25-student-progress vs 43-superadmin-analytics, both widths] LOW — Two GitHub-style activity heatmaps, two unrelated color ramps.** Student Progress uses a green scale (Less → light green → green → dark green → darkest green). Super Admin's Platform Activity Heatmap uses a grey/amber/orange/navy scale for the identical widget type and legend format ("Less ... More"). **Why it matters:** small, but it's a real, easily-fixed design-system gap — same component, two different palettes. **Fix:** one shared heatmap color-ramp component, used by both.

**8. [42-superadmin-dashboard, both widths] Flag, not a confirmed finding — page length itself is a signal.** At 15,000+ px (desktop) and nearly 18,000px (mobile), this is by far the longest page in the entire product by an order of magnitude, consistent with rendering a full, flat, unpaginated user table. Even Admin's long content lists (Section 5, #5/#6 above) at least have a "Load more" button. **Worth checking:** does this page paginate, virtualize, or search at all? If not, it will get materially worse as the user base grows past ~170.

**9. [43-superadmin-analytics] Worth verifying, not asserting — "28 students" for CA Intermediate looks low.** The Course Cohort Comparison table lists CA Intermediate at 28 students, while every other reference to this course elsewhere in the product implies it's the largest cohort (~160+ students). This may simply mean the "Students" column here counts something narrower (e.g., "reviewed in this window") rather than total enrollment — I can't tell which from the screenshot, but it's worth a quick manual check rather than assuming either way.

**Positive, worth calling out — a correct reference implementation:** **Super Admin Analytics' "Course Cohort Comparison" table does the amber-row legend right**: it states directly beneath the table, "Amber rows = zero reviews this week," and the amber-highlighted CA Final row genuinely has zero reviews. This is exactly the self-documenting pattern Professor Analytics' broken caption (Section 4, finding #1) should have followed — worth using this table as the template when fixing that one.

---
# Final Wrap-Up — Cross-Page Consistency Audit & Top 5

## The one theme that dominates everything else: numbers don't agree with themselves

This is worth stating plainly before anything else, because it's the single most-repeated finding across all five sections **and** the earlier public-site review: **the same metric shows different values depending on which page you look at, with no explanation anywhere.**

- Public landing page: hero says 2,183 flashcards / 128 notes; a section below says 693 / 107 (flagged in the earlier public-pages audit).
- Admin Dashboard says 169 Total Users; Admin Analytics and Super Admin Analytics both say 171.
- Admin Analytics says CA Intermediate has 458 published items; Super Admin Analytics says 544 for the same course.

Three separate instances, on three completely different surfaces (marketing site, admin tooling, super-admin tooling), all the same shape of bug: a stat card reading from a stale/cached/differently-scoped source than its sibling page. For a product whose whole value proposition is precision and trustworthy tracking (accuracy %, mastery %, quality scores), this is the thing most likely to quietly erode confidence in every other number on screen — including the ones that matter to a student's actual study decisions. **This should be treated as one ticket — "audit every stat card's data source and reconcile" — not five separate copy fixes.**

## Cross-page consistency findings, organized by dimension

**Navigation / wayfinding**
- Active-nav-item highlighting works on top-level landing routes (Dashboard, Create, Groups, Study's Browse Notes) but silently disappears on "my content" pages and in-progress review sessions (My Flashcards, My Notes, My Contributions, Study Mode, Review Session). Confirmed across 9+ pages in Sections 1–2. This is the single cleanest, most systemic, cheapest-to-fix consistency bug in the whole review.
- Confirmed definitively in Section 4: the "Analytics + course-switcher" nav variant seen in 16-review-session belongs to the Professor role — that screenshot should be re-captured with a genuine student account before anyone treats its nav as representative of the student experience.

**Data semantics / color-coding**
- Quality-tier colors (Easy/Medium/Hard) are implemented at least twice with different thresholds and one wrong caption: Professor Analytics' amber caption describes the red tier's range; Admin Analytics colors exactly 4.0 amber despite Professor Analytics' own donut legend defining "Easy" as ≥4.0. Needs one shared color-threshold utility.
- "Due Today: 0" is styled as an alert (red) on Progress, while the same underlying state ("nothing due") is styled as a celebration on the Dashboard. Same real-world fact, opposite emotional coloring depending on page.

**Information density / list patterns**
- Three different defaults for "browse a list of content" exist side by side: Browse Notes collapses to click-to-expand subject summaries; Review Flashcards / My Flashcards show full preview cards inline; Find Friends uses a single full-width column where a card grid (already used elsewhere) would fit naturally.
- Wide data tables have two different, both-imperfect mobile strategies: Professor Analytics silently drops columns with no scroll hint; Admin Dashboard crams all 7 columns into unreadable mobile cells. Neither is a designed solution — both need the same fix (responsive card layout or a visible scroll affordance), applied once and reused.

**Component reuse**
- Badges are shown two ways for the same concept: Author Profile labels each badge with text (does it right); Find Friends shows the same badges as tiny unlabeled colored icon clusters, 30 times down one page (does it wrong). One component should serve both.
- Two GitHub-style activity heatmaps (Student Progress, Super Admin Analytics) use two unrelated color ramps for the identical widget type.
- "Quick Actions" is reimplemented at least twice (Dashboard, My Contributions) with different verbs for the same actions (Browse vs. View) — evidence it isn't a shared component yet.

**Brand tone**
- My Achievements is the one page that reads as gamified (trophies, locks, "you are a legend" copy) against an otherwise calm, restrained product — the clearest single outlier against your stated "not gamified" direction. This is a product/content call, not a quick fix, but worth a deliberate decision rather than letting it stand by default.

**A methodology note, not a design finding:** the sticky-header-overlapping-content issue seen on Note Detail and Author Profile (desktop) is very likely a GoFullPage capture artifact rather than a live bug — recommend a 30-second manual scroll-check on the real site before spending engineering time on it, and don't trust GoFullPage captures for judging any page with a sticky header going forward.

---

## Top 5, ranked by impact-to-effort

1. **Fix active-nav highlighting to match on route prefix, not just exact top-level routes.** Cheapest fix on this list (one piece of shared logic), and it's currently broken on roughly half the logged-in app. Highest ROI item in the whole review.
2. **Audit and reconcile every stat card's data source** (Admin Dashboard vs. Admin Analytics' Total Users; Admin Analytics vs. Super Admin Analytics' published-items counts; plus the public-site flashcard/notes counts from the earlier review). One investigation, likely one shared root cause (stale cache or inconsistent query scope), highest trust impact of anything found.
3. **Extract quality-tier color thresholds (Easy/Medium/Hard) into one shared utility and fix Professor Analytics' caption.** Cheap, and it's actively misleading the exact audience (professors, admins) who rely on this page to make content decisions.
4. **Give Find Friends' badge icons text labels, matching Author Profile's pattern.** The component to copy already exists in your own product — this is a reuse job, not new design work.
5. **Give wide tables (Professor Analytics, Admin Dashboard) one real mobile strategy** — either a responsive card layout or a visible horizontal-scroll cue — instead of two different broken ones. Slightly more effort than the others here, but it's the same fix needed in two places at once.

**Honorable mention, higher effort than the above but worth planning for:** add search/filter to Admin's content-moderation lists (they currently have less filtering than the student-facing pages showing the same content) — this won't hurt today at ~170 users, but it will become a real operational bottleneck well before the next order-of-magnitude growth milestone.
