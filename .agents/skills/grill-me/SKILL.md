---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. Provide a recommendation with every question. Ask one question at a time.

If a question can be answered by exploring the codebase, explore the codebase instead of asking.

For the *format* of every question you ask the user, follow the `asking-user-questions` skill — it covers chip-based `AskUserQuestion` formatting, hierarchical IDs for text fallback, composite-decision splitting (batch acceptance + embedded design points), and anti-narration. Load and apply it on every grill turn that requires user input.
