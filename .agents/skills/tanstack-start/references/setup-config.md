# Setup And Configuration

Use this when creating, reviewing, or repairing the shape of a TanStack Start React project.

## Package Surface

Core packages normally include:

- `@tanstack/react-start`
- `@tanstack/react-router`
- `@tanstack/router-plugin`
- `vite`
- `typescript`

Common serious-app additions:

- `@tanstack/react-query`
- `@tanstack/react-router-ssr-query`
- validation library: `zod`, `valibot`, `arktype`, or `effect`
- `@tanstack/zod-adapter` when Zod adapter behavior is needed

Use the existing package manager from `package.json`. Do not mix `npm`, `pnpm`, `bun`, and `yarn`.

## Vite Config

Check `vite.config.ts` for:

- `tanstackStart(...)` plugin
- React plugin
- TypeScript path aliases
- prerender config
- SSR/runtime target adapters
- import protection settings if customized

Typical shape:

```ts
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import tsConfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsConfigPaths(), tanstackStart(), react()],
})
```

Keep plugin order consistent with the app's current template and docs. If a project already has a deployment adapter or monorepo plugin, preserve it.

## Route Generation

`src/routeTree.gen.ts` is generated. Never edit it manually.

When route types look stale:

- run the dev server, build, or the project's route generation script
- check that the route file exports `Route`
- check `createFileRoute('/path')` path matches the generated route ID
- check ignored route prefixes and route file naming conventions
- restart the TypeScript server if the editor is stale

## Root Route And Document Shell

The root route should own the document shell:

```tsx
import {
  HeadContent,
  Outlet,
  Scripts,
  createRootRouteWithContext,
} from '@tanstack/react-router'

export const Route = createRootRouteWithContext<RouterContext>()({
  head: () => ({
    meta: [{ title: 'App' }],
  }),
  component: RootDocument,
})

function RootDocument() {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        <Outlet />
        <Scripts />
      </body>
    </html>
  )
}
```

Check:

- `HeadContent` is in `<head>`
- `Scripts` is before `</body>`
- global providers are placed where Start/Router expects them
- `createRootRouteWithContext` is used when router context is typed

## Head, Metadata, And SEO

Use route `head` for title/meta/links/scripts that belong to a route.

```tsx
export const Route = createFileRoute('/posts/$postId')({
  loader: ({ params, context }) =>
    context.queryClient.ensureQueryData(postQuery(params.postId)),
  head: ({ loaderData }) => ({
    meta: loaderData
      ? [
          { title: loaderData.title },
          { name: 'description', content: loaderData.excerpt },
        ]
      : undefined,
  }),
})
```

Do not hardcode per-route metadata in the root document when it depends on route data.

## Path Aliases

Prefer the project alias over deep relative imports. Common aliases:

- `~/` for app source
- `@/` for app source
- workspace package aliases in monorepos

When fixing imports:

- inspect `tsconfig.json`
- inspect `vite.config.ts`
- preserve the existing alias convention
- avoid barrel imports that mix server-only and client-safe modules

## Entry Points

Only customize entries when the app needs it.

- `src/client.tsx`: client hydration entry
- `src/server.ts`: server entry/custom server behavior
- `src/start.ts`: Start instance config such as global middleware and defaults

Do not add custom entries for ordinary routing/data work.

## Database And Service Placement

Put DB clients and privileged service SDKs behind server-only boundaries:

```text
src/server/db.server.ts
src/server/auth.server.ts
src/features/projects/projects.functions.ts
```

Client-safe types and schemas can live beside features, but runtime DB/secrets should not be imported by route components or shared barrels.
