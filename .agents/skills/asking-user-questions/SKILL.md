---
name: asking-user-questions
description: Use whenever you are about to ask the user for a decision or input mid-task — covers `AskUserQuestion` chip formatting, hierarchical IDs for text fallback, composite-decision splitting, and anti-narration to minimize the user's typing. Apply inside any skill or workflow that requires user input on a choice; this is meta-guidance about HOW to ask, complementing whatever skill triggered the task. Especially important when there are multiple decisions, sub-points, or more than 4 options.
---

When you ask the user a question that requires their decision input, optimize the turn against these rules. The user's typing budget is the scarce resource.

## R1. Default to `AskUserQuestion`

If the answer space is enumerable in 2–4 options, ask via the `AskUserQuestion` tool. Header chip ≤12 chars. List your recommended option first AND suffix its `label` with `(Recommended)` — the suffix on the chip itself is required, not optional. Do not substitute a prose preamble for it; the user is scanning chips, not paragraphs, and an unlabeled "listed first" recommendation reads as arbitrary ordering. Give each option a one-line `description` explaining the tradeoff. Do not add a manual "Other" — the tool supplies one.

"Enumerable" means the option list is plausibly complete. If you'd expect `Other` to be a likely answer (open-ended naming, free-form prose, anything where you're really fishing for the user's own idea), R1 doesn't fit — drop to R2 and offer your candidate suggestions inline as text. Forcing chips on a free-form decision turns the `Other` escape into the default path, which defeats the chip UX.

## R2. Fallback: hierarchical IDs

When `AskUserQuestion` doesn't fit (>4 options, free-form input needed, or a true tree of follow-ups), ask in text but format options as a non-overlapping ID grid. IDs must carry breadcrumbs back to their parent: a child of `d3` is `d3.i`, `d3.ii`, `d3.iii` — never bare `i/ii/iii`. The user must be able to scroll back several turns, reply with just the deepest ID (e.g. `d3.ii`), and have it be unambiguous across the entire conversation. One question per turn. Tell the user they can reply with just the ID.

Before reaching for the grid, check whether the options compress into ≤4 chips by grouping — often the recommendation plus "show me the alternatives" works as a macro/micro split per R3, where the macro chip is the one-click happy path and the micro chip opts into the full ID grid. Grid is the fallback when compression genuinely loses information the user needs to choose well.

## R3. Composite decisions — separate the three question types

When proposing a batch of drafted items that contains one or more embedded design points, never stack them in one turn. Split into:

- **(a) Batch acceptance.** One `AskUserQuestion` with two chips: `Accept as drafted (Recommended)` / `I want to edit specific items`.
- **(b) Each embedded design point.** Its own `AskUserQuestion` call (or R2 ID-grid fallback). One design point per turn.
- **(c) Open-ended edits.** Never a default tail on another question. Only fire if the user picks "edit" in (a), and even then phrase it as "which IDs?" not free-form.

Sequence the turns: resolve every design point in (b) first, then ask batch acceptance in (a) against a fully-specified draft. This avoids accepting a draft that still has holes, and avoids pre-committing to a recommendation by silence.

## Don't narrate the rules to the user

The chip, the grid, the turn-split *is* your answer to the rule — you don't need to also recite or quote the rule. Save your reasoning about which rule applies for yourself; the user sees the question, not the meta-explanation.

## Worked example — the kind of turn to avoid

Bad (one turn, three stacked question types, overlapping IDs):

> Take A through D as drafted, with your call on (d3)? Anything to add, remove, or move? And on integrity specifically, do you want (i), (ii), or (iii)?

Good (three short turns):

1. Design point d3 via `AskUserQuestion`, header `Integrity`, options `d3.ii Audit-trail (Recommended)` / `d3.iii WORM-or-audit, defer` / `d3.i WORM only`.
2. Batch acceptance via `AskUserQuestion`, header `Accept A–D`, options `Accept as drafted (Recommended)` / `Edit specific items`.
3. Only if the user picked "Edit": text turn asking `Which IDs to edit?` listing `a1 a2 b1 b2 c1 c2 c3 d1 d2 d4 d5` (d3 already settled). Reply with IDs.

Best case: two chip clicks. Worst case: no free-form typing until the user has explicitly opted into editing.
