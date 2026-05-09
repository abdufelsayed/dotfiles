# Product UI

Use this for SaaS apps, admin panels, dashboards, tables, forms, settings, internal tools, and workflow-heavy product screens.

## Product Goal

Product UI is not a showcase. It should help users understand state, make decisions, and complete tasks with low cognitive load. Visual quality matters, but it should come from hierarchy, alignment, spacing, typography, useful affordances, and coherent states.

Before coding, answer:

- What is the user's primary job on this screen?
- What information must be visible immediately?
- What action should be easiest to find?
- What decisions need comparison, filtering, scanning, or confirmation?
- What can be collapsed, grouped, delayed, or removed?

## Composition Principles

- Put the primary workflow in the most stable, central area of the page.
- Make the primary action obvious, but avoid turning every action into a button.
- Use tables and structured lists for repeated operational data; avoid card grids when users need to compare rows.
- Group controls by task and consequence, not by backend schema.
- Keep filters, search, and bulk actions close to the data they affect.
- Make status visible where it changes decisions; do not decorate every row with badges.
- Prefer section rhythm, dividers, whitespace, and typography before adding more cards or borders.
- Avoid nested cards unless the nesting maps to a real information hierarchy.
- Use icons when they improve recognition, save space, or clarify repeated controls; do not use icons as filler.
- Keep destructive, irreversible, or high-consequence actions visually distinct and protected by confirmation when appropriate.

## Common Product Surfaces

### Dashboards

- Lead with the most actionable summary, not every available metric.
- Show trends and exceptions when they change what the user should do next.
- Keep charts purposeful. Do not add charts for numbers that are easier to read as text.
- Prefer a compact overview plus drill-down paths over a dense wall of widgets.

### Tables and Lists

- Prioritize columns by scanning value and decision value.
- Put row actions in a consistent place.
- Use density intentionally: product users often need compact layouts, but clutter still slows them down.
- Empty states should explain what is missing and offer the next useful action.

### Forms

- Order fields by the user's mental model and decision flow.
- Group related inputs under clear labels.
- Use progressive disclosure for uncommon or advanced fields.
- Inline validation should be specific and placed close to the problem.
- Avoid helper text unless it prevents real mistakes.

### Settings

- Group settings by consequence, frequency of use, and ownership.
- Make current state clear before offering changes.
- Separate safe everyday preferences from risky account, billing, security, or integration changes.
- Prefer explicit save/cancel behavior for multi-field changes where accidental persistence is risky.

## Visual Tone

- Default to neutral surfaces, semantic feedback colors, and one clear accent.
- Match local spacing, radius, border, shadow, and focus conventions.
- Use restrained motion for state changes, disclosure, and feedback.
- Avoid novelty styling, random saturated colors, heavy gradients, and decorative backgrounds unless the product already uses them.

## Product UI Quality Bar

The result should feel quiet, capable, and hard to misuse. A strong product interface usually looks simpler after the design pass because weak hierarchy, duplicate metadata, scattered actions, and decorative noise have been removed.
