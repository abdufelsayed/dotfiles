# UI Pattern Sources

Use these sources in this order.

## shadcn CLI

- Official CLI docs: `https://ui.shadcn.com/docs/cli`
- Prefer the project's package runner from `packageManager`:
  - `npx shadcn@latest`
  - `pnpm dlx shadcn@latest`
  - `yarn dlx shadcn@latest`
  - `bunx --bun shadcn@latest`
- Use `shadcn info` to confirm project context before changing imports, tokens, or component source.
- Use `shadcn docs <component>` to get official docs, example, and API URLs.
- Use `shadcn search <registry> -q "<query>"` to discover registry items.
- Use `shadcn view <item>` to inspect registry item details and file contents before installing.
- Use `shadcn add <item> --view [path]` to preview the exact project-resolved file contents that would be written.
- Use `shadcn add <item> --diff [path]` to compare upstream source against existing local files.
- Prefer `add --view` or `add --diff` over raw URLs when the preview needs project aliases, resolved paths, CSS changes, or local diffs.

## REUI Registry

- Registry docs: `https://reui.io/docs/registry`
- Add the REUI namespace to `components.json` when it is missing:

```json
{
  "registries": {
    "@reui": "https://reui.io/r/{style}/{name}.json"
  }
}
```

- Use REUI item names through the shadcn CLI:
  - `shadcn view @reui/c-accordion-1`
  - `shadcn add @reui/c-accordion-1 --view`
  - `shadcn add @reui/filters --view`
- Prefer the REUI visual catalog to discover item names, then use `shadcn view @reui/<name>` to inspect source.
- If `shadcn search @reui` cannot read a registry index, do not fall back to manual GitHub scraping for discovery. Use the visual catalog, then inspect the selected item through `shadcn view`.

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

- Fallback only. Prefer `shadcn view @reui/<name>` for source inspection.
- URL template: `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns/<component>`
- Examples:
  - `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns/select`
  - `https://github.com/keenthemes/reui/tree/main/registry-reui/bases/base/patterns/avatar`
- Use this to list available `p-<component>-<n>.tsx` files.

## Raw Pattern File

- Fallback only. Prefer `shadcn view @reui/<name>` or `shadcn add @reui/<name> --view [path]`.
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
