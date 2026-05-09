# Implementation Checklist

Use this before finishing substantial UI work.

## Local Fit

- Matches nearby route layouts, shared primitives, and package boundaries.
- Uses existing tokens for surfaces, text, borders, rings, radii, shadows, and semantic states.
- Preserves existing component APIs unless a redesign required changing them.
- Uses composition before adding new variants or broad props.

## UX Fit

- Primary user goal is visible in the layout.
- Primary and secondary actions are clearly distinguished.
- Information hierarchy supports scanning and decision-making.
- Controls are grouped by task and effect.
- Empty, loading, error, disabled, hover, focus, selected, and active states are handled when relevant.
- Destructive or high-consequence actions are appropriately separated or confirmed.

## Visual Fit

- No unnecessary nested cards, badges, borders, icons, shadows, helper text, or decorative fills.
- Text fits inside its containers across mobile and desktop viewports.
- Spacing and alignment feel intentional.
- Product UI stays coherent with the system; marketing UI has a clear and consistent visual direction.

## Accessibility and Behavior

- Keyboard behavior and focus management come from accessible primitives when possible.
- Focus states are visible.
- Labels, descriptions, and error messages are associated with controls.
- Color is not the only indicator of status or validation.
- Responsive behavior preserves the main task.

## Verification

- Run the relevant typecheck, lint, tests, or build command when available.
- For visual frontend changes, open the page in a browser when the app can run locally and inspect desktop and mobile widths.
- If verification cannot be run, state what was skipped and why.
