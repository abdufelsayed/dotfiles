---
name: interface-design
description: UI and UX design guidance for product interfaces, SaaS/admin tools, dashboards, forms, settings, reusable components, and SaaS marketing pages. Use when creating, restyling, or extending visual surfaces in React, Tailwind, shadcn/ui, Base UI, or similar frontend projects. Guides agents to choose the right mode, compose the experience before coding, inspect local patterns, use external references when useful, and avoid cluttered or confusing interfaces.
---

# Interface Design

Use this skill for UI creation and UI update tasks. Its purpose is to make agents think through the user experience and visual composition before assembling components.

## Start Here

First identify the work mode:

- **Product UI**: SaaS apps, admin panels, dashboards, tables, forms, settings, internal tools, and workflow screens. Read [product-ui.md](references/product-ui.md) and [composition.md](references/composition.md).
- **SaaS marketing**: landing pages, pricing pages, feature pages, conversion pages, and signup-entry experiences. Read [saas-marketing.md](references/saas-marketing.md) and [composition.md](references/composition.md).
- **Component work**: reusable components, design-system primitives, app-level compositions, and stateful controls. Read [composition.md](references/composition.md) and, when implementation patterns are unclear, [pattern-discovery.md](references/pattern-discovery.md).

Read only the references that match the task. For small local edits, apply the relevant principles without turning the change into a large research pass.

## Core Workflow

1. Understand the user task.
   - Identify the primary user goal, the decision the UI supports, and the most important action.
   - Decide what information belongs at first glance, what can be secondary, and what can be hidden or removed.

2. Compose before coding.
   - Sketch the hierarchy mentally: page regions, groups, controls, data, status, and actions.
   - Choose the simplest structure that supports the workflow.
   - Prefer fewer stronger groups over many visually competing cards, badges, icons, and helper texts.

3. Inspect the local system.
   - Search for nearby screens, route layouts, shared components, primitives, tokens, spacing, and interaction patterns.
   - Reuse existing imports, slot names, package boundaries, `cn()`, radii, focus rings, semantic tokens, and accessibility primitives.
   - Preserve the existing component API unless the task asks for a redesign.

4. Use references when helpful.
   - Use external pattern sources when the local system does not provide a clear composition pattern, or when a complex surface benefits from proven examples.
   - Match by job-to-be-done, not just component name.
   - Borrow structure, density, interaction patterns, and state handling; translate visuals into the local design system.

5. Verify the result.
   - Check the relevant empty, loading, error, disabled, focus, hover, selected, active, and mobile states.
   - Confirm the visual hierarchy supports the main task and the UI is not cluttered.
   - Use [implementation-checklist.md](references/implementation-checklist.md) for final review on substantial UI work.

## Default Bias

Product UI should converge on one coherent system: predictable, calm, useful, and easy to scan. SaaS marketing pages may be more expressive, but should still have a clear audience, offer, conversion path, and proof.

Avoid strict universal rules when context matters. Prefer judgment that keeps the interface clear: if an element does not improve comprehension, action, feedback, trust, or navigation, remove it or make it quieter.
