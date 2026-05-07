---
name: frontend-design-best-practices
description: Research-first UI design and implementation guidance for React, Base UI, shadcn/ui, and Tailwind work. Use whenever you are creating, restyling, or extending a UI component, page section, form, dashboard card, navigation element, empty state, or other visual surface. This skill requires inspecting existing repo patterns first, then studying matching shadcn registry sources and REUI/Base UI patterns before writing code so the result stays simple, coherent, accessible, and visually restrained.
---

# UI Pattern First

Treat this skill as mandatory for UI creation and UI update tasks.

## Overview

Do not invent UI from scratch when an existing pattern already solves the problem. Before writing code, inspect the local design system, then inspect relevant shadcn registry sources and at least one relevant REUI pattern when visual pattern guidance is needed. Favor calm, coherent interfaces: simple structure, clear hierarchy, restrained motion, and the existing token palette.

## Required Workflow

1. Inspect the local repo first.
   - Search `packages/ui/src/components` for an existing primitive or close cousin.
   - Search `apps/web/src/components` and the relevant route files for current composition patterns.
   - Reuse existing imports, slot names, radii, spacing rhythm, and semantic tokens such as `bg-card`, `text-muted-foreground`, `ring-foreground/10`, `bg-muted`, `border-input`, and `focus-visible:ring-ring/50`.
   - Keep using `cn()` and the current package boundaries.

2. Find matching shadcn and REUI references before coding.
   - For shadcn/ui projects, use the project's package runner from `packageManager`: `npx shadcn@latest`, `pnpm dlx shadcn@latest`, `yarn dlx shadcn@latest`, or `bunx --bun shadcn@latest`.
   - Run `shadcn info` when project context is missing or stale so imports, aliases, Tailwind version, base library, icon library, and installed components are not guessed.
   - Use `shadcn docs <component>` for component docs, examples, and API URLs before implementing or changing a shadcn component.
   - Use `shadcn search <registry> -q "<query>"` to find registry items by job-to-be-done.
   - Use `shadcn view <item>` to inspect registry item details and file contents before installing an item, especially namespaced registry items such as `@shadcn/button`, `@tailark/...`, or `@v0/...`.
   - Use `shadcn add <item> --view [path]` when you need a project-aware preview of the exact files the CLI would write. Use `shadcn add <item> --diff [path]` for existing components or CSS changes. These preview commands imply dry-run behavior.
   - Do not fetch raw registry files manually when `shadcn view` or `shadcn add --view` can show the source through the CLI.
   - For REUI, make sure `components.json` has the `@reui` registry namespace: `"@reui": "https://reui.io/r/{style}/{name}.json"`.
   - For REUI pattern discovery, start with the visual catalog: `https://reui.io/patterns/<component>`.
   - If the component name is unclear, search the visual catalog: `https://reui.io/patterns?search=<query>`.
   - Read the pattern names and short descriptions on the docs first so you know what each numbered variant is for before fetching code.
   - Use those labels to shortlist by purpose. Example: accordion pattern `1` maps to `@reui/c-accordion-1`, so inspect it with `shadcn view @reui/c-accordion-1`.
   - If `shadcn search @reui` cannot read a registry index, use the REUI visual catalog for discovery and `shadcn view @reui/<name>` for source inspection.
   - If you need code, prefer `shadcn view @reui/<name>` or `shadcn add @reui/<name> --view [path]`. Use GitHub folders or raw URLs only as a fallback when the registry or CLI is unavailable. See [references.md](references.md).
   - Match by structure and job-to-be-done, not only by component name. A settings picker may map to `select`, `dropdown-menu`, `combobox`, or `command`.

3. Choose a pattern direction.
   - Pick one to three candidate shadcn registry items or REUI patterns by name, number, and stated purpose from the docs.
   - Note what you are borrowing: layout, density, slot composition, affordances, spacing, icon treatment, or state handling.
   - Prefer the simplest pattern that satisfies the UX.

4. Adapt to this project.
   - Do not paste REUI code blindly. Translate it into local `@starter/ui` primitives and current tokens.
   - Preserve the existing component API unless the task explicitly asks for a redesign.
   - Prefer composition over adding new variants or props.
   - Keep text hierarchy strong and wrappers minimal.

5. Verify the result.
   - Check empty, loading, error, disabled, focus, hover, selected, and mobile states when relevant.
   - Ensure keyboard and focus behavior still comes from Base UI primitives.
   - Remove decorative noise that does not improve comprehension.

## Design Rules

- Use the existing palette and tokens first. This repo already defines a neutral surface system with a single primary accent in `packages/ui/src/styles/globals.css`.
- Avoid loud, clashing, or novelty colors. Do not introduce random saturated colors, rainbow accents, or gradient-heavy treatments unless the user explicitly asks for that direction.
- Favor one clear accent, neutral surfaces, and semantic feedback colors.
- Prefer calm density: enough whitespace to separate groups, but do not pad everything into oversized cards.
- Use typography and spacing to create hierarchy before reaching for extra borders, icons, badges, or background fills.
- Keep motion minimal and purposeful.
- When an existing screen already has a style, preserve it instead of importing a foreign visual language.

## Pattern Selection Heuristics

- `select`, `native-select`, `combobox`, `command`: choice inputs, searchable pickers, assignment menus
- `avatar`, `avatar-group`: people, owners, participant stacks, team indicators
- `card`, `table`, `tabs`, `accordion`, `drawer`, `dialog`: structural containers and information grouping
- `empty`, `alert`, `tooltip`, `badge`: supporting states and secondary affordances

If the component category is unclear, inspect shadcn search results and the REUI pattern index first, then choose by job-to-be-done.

## Local Style Anchors

Use these local files as anchors before introducing anything new:

- `packages/ui/src/components/select.tsx`
- `packages/ui/src/components/avatar.tsx`
- `packages/ui/src/components/card.tsx`
- `packages/ui/src/styles/globals.css`

These files show the current radius, ring, surface, muted text, and spacing conventions. Match those conventions unless the user explicitly requests a new visual direction.

## Output Standard

When you finish a UI change, make sure the result is:

- Beautiful: clear hierarchy, balanced spacing, polished states
- Coherent: matches nearby screens and shared primitives
- Simple: no unnecessary layers, props, colors, or effects

If you cannot find a fitting local pattern or a relevant REUI example, say so explicitly and explain the fallback you chose instead of improvising an arbitrary design.
