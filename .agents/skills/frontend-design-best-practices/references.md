# REUI Sources

Use these sources in this order.

## Visual Catalog

- URL template: `https://reui.io/patterns/<component>`
- Search URL: `https://reui.io/patterns?search=<query>`
- Examples:
  - `https://reui.io/patterns/select`
  - `https://reui.io/patterns/avatar`
  - `https://reui.io/patterns?search=multi-select`
- Use this first to compare multiple pattern variants quickly.
- The docs expose each pattern's number, name, and intended purpose. Use that metadata to choose the right variant before opening code.
- Example: avatar pattern `3` is `Avatars with different sizes`, so the matching raw file is `p-avatar-3.tsx`.

## GitHub Pattern Folder

- URL template: `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns/<component>`
- Examples:
  - `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns/select`
  - `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns/avatar`
- Use this to list available `p-<component>-<n>.tsx` files.

## Raw Pattern File

- URL template: `https://raw.githubusercontent.com/keenthemes/reui/main/registry-reui/bases/base/patterns/<component>/p-<component>-<n>.tsx`
- Example:
  - `https://raw.githubusercontent.com/keenthemes/reui/main/registry-reui/bases/base/patterns/select/p-select-1.tsx`
- Use this when you want the code directly without GitHub page chrome.
- Build the raw URL from the component name plus the pattern number you selected from the docs.
- Pattern files also include top comments such as `Description:` and `Order:`. Use those comments as a fallback if the docs page is unavailable.

## Pattern Index

- URL: `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns`
- Use this when you do not know the component category yet.
- Common categories observed in the repo include `accordion`, `alert`, `autocomplete`, `avatar`, `badge`, `breadcrumb`, `select`, `stepper`, `switch`, `table`, `tabs`, `textarea`, `timeline`, `toggle`, `tooltip`, and `tree`.

## Adaptation Notes

- REUI pattern files commonly export `Pattern` and import from `@/registry/bases/base/ui/...`.
- Treat those imports as reference implementations, not as drop-in imports for this repo.
- Map REUI structure into local `@starter/ui/components/...` primitives or existing app-level compositions.
- Copy layout, density, and interaction ideas. Do not copy branding blindly.
