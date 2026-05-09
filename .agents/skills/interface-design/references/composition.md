# Visual Composition

Use this for all UI modes. It focuses on how components become a coherent interface instead of a pile of primitives.

## Think in Hierarchy

Before writing code, decide:

- Page structure: navigation, header, main content, sidebars, panels, and footers.
- Information hierarchy: primary, secondary, supporting, and hidden details.
- Action hierarchy: primary action, common secondary actions, rare actions, destructive actions.
- State hierarchy: what needs immediate attention, what can be subtle, and what can be shown only on interaction.

The layout should make those priorities visible without relying on explanatory text.

## Reduce Clutter

Clutter is not just too much content. It is too many competing visual claims.

Look for:

- Too many bordered boxes, nested cards, badges, icons, shadows, or background fills.
- Metadata shown at the same weight as primary content.
- Controls scattered across the surface instead of grouped by task.
- Helper text that repeats labels or explains obvious controls.
- Multiple button styles competing in one area.
- Decorative elements that do not improve comprehension, trust, navigation, action, or feedback.

Remove, group, or quiet these before adding new UI.

## Grouping and Density

- Use proximity to show relationships before adding borders.
- Use section headers when they help scanning, not for every small group.
- Use compact density when users need comparison or repeated action.
- Use more whitespace for unfamiliar, high-consequence, or marketing-oriented content.
- Keep repeated items stable in size so hover states, labels, icons, and loading states do not shift layout.

## Controls and Affordances

- Use buttons for commands, links for navigation, toggles/checkboxes for binary settings, selects/comboboxes for choices, tabs for peer views, dialogs/drawers for focused temporary work, and tables/lists for repeated data.
- Put controls where users expect their effect to apply.
- Keep primary actions visually distinct but not oversized inside dense product surfaces.
- Avoid making every row or field feel interactive when only a small part is actionable.

## Copy and Labels

- Labels should be concrete and short.
- Button text should describe the action, not the UI mechanism.
- Empty states should explain the missing state and offer the next useful action when one exists.
- Error text should explain what happened and what the user can do.
- Avoid visible instructional copy that compensates for weak layout.

## Responsive Composition

- Decide what collapses, stacks, hides, or becomes a menu before writing markup.
- Preserve the main action path on mobile.
- Tables need a deliberate mobile treatment: horizontal scroll, priority columns, cards, or detail views depending on use case.
- Check that text fits in buttons, cards, tabs, headers, and sidebars without overlap.

## Visual Finish

A polished interface usually has fewer layers, clearer alignment, stronger spacing rhythm, and more consistent states than the first draft. Treat visual polish as editing: clarify, align, remove, and only then embellish.
