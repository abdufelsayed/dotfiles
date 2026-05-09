# Routing, Context, Params, And Validation

TanStack Start uses TanStack Router. Treat routing as the backbone of the app, not a thin URL switch.

## File Routing Conventions

- `src/routes/__root.tsx`: root route and full document shell.
- `index.tsx`: index route for a directory/path.
- `posts.tsx` or `posts.route.tsx`: parent route.
- `posts.$postId.tsx` or `posts/$postId.tsx`: dynamic param.
- `_authenticated.tsx`: pathless layout route. It does not add a URL segment.
- `posts_.$postId.deep.tsx`: break out of parent nesting with trailing `_`.
- `-internal.tsx`: excluded from route tree when using ignore prefix.
- `routeTree.gen.ts`: generated. Never edit.

Prefer pathless layout routes for cross-cutting behavior like auth, shared loaders, shared layout, breadcrumbs, and route context augmentation.

## Route Lifecycle

On navigation, Router generally does:

1. match routes top-down
2. parse path params
3. validate search
4. run `beforeLoad` parent before child
5. run loaders in parallel
6. render components or error/pending boundaries

This matters because `beforeLoad` can add context used by child `beforeLoad` and loaders. Search validation happens before `beforeLoad`, so validated search is available there.

## Router Context Vs Route Context

Use router context for dependencies and cross-route state that route code needs outside React hooks.

```tsx
// src/routes/__root.tsx
import { createRootRouteWithContext } from '@tanstack/react-router'
import type { QueryClient } from '@tanstack/react-query'

type RouterContext = {
  queryClient: QueryClient
  auth?: { userId: string; role: 'user' | 'admin' } | null
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootComponent,
})
```

```tsx
// src/router.tsx
export function getRouter() {
  const queryClient = new QueryClient()

  return createRouter({
    routeTree,
    context: {
      queryClient,
      auth: null,
    },
  })
}
```

Route `beforeLoad` can augment context for descendants:

```tsx
export const Route = createFileRoute('/_authenticated')({
  beforeLoad: async ({ context, location }) => {
    const user = await getCurrentUser()
    if (!user) throw redirect({ to: '/login', search: { redirect: location.href } })
    return { auth: { userId: user.id, role: user.role } }
  },
})
```

Distinctions:

- Router context is passed to route options outside React.
- React context is for component trees and hooks.
- Middleware context is for server request/function chains.
- Server function `context` is produced by server function middleware.

Do not mix these up. Route context can describe the page decision; server function context must enforce server-side authorization.

## Path Params

Path params come from `$segment` route names and are strings by default.

```tsx
export const Route = createFileRoute('/orgs/$orgId/projects/$projectId')({
  loader: async ({ params, context }) => {
    return context.queryClient.ensureQueryData(
      projectQuery(params.orgId, params.projectId),
    )
  },
})
```

Treat params as untrusted user input. If an ID must be a UUID, slug, number, or belongs to a tenant, validate before business use. Do tenant/ownership checks on the server, not only in route code.

## Search Params As Typed URL State

TanStack Router search params are not just strings. They are JSON-first URL state with structural sharing and typed validation.

Use `validateSearch` at the route boundary:

```tsx
import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'

const searchSchema = z.object({
  page: z.number().catch(1),
  q: z.string().catch(''),
  sort: z.enum(['newest', 'oldest']).catch('newest'),
})

export const Route = createFileRoute('/projects')({
  validateSearch: searchSchema,
  loaderDeps: ({ search }) => ({
    page: search.page,
    q: search.q,
    sort: search.sort,
  }),
  loader: ({ deps, context }) =>
    context.queryClient.ensureQueryData(projectsQuery(deps)),
})
```

Use route-local hooks for strongest types:

```tsx
function ProjectsToolbar() {
  const search = Route.useSearch()
  const navigate = Route.useNavigate()

  return (
    <button onClick={() => navigate({ search: (prev) => ({ ...prev, page: prev.page + 1 }) })}>
      Next
    </button>
  )
}
```

For components outside the route module, use `getRouteApi('/projects')` or `useSearch({ from: '/projects' })`.

## Navigation Rules

Use typed navigation objects. Do not build URLs by interpolating params/search manually.

Good:

```tsx
<Link
  to="/orgs/$orgId/projects/$projectId"
  params={{ orgId, projectId }}
  search={(prev) => ({ ...prev, tab: 'settings' })}
/>
```

Bad:

```tsx
<Link to={`/orgs/${orgId}/projects/${projectId}?tab=settings`} />
```

Use functional `search` updates when changing one piece of URL state and preserving the rest.

## Search Middlewares

Use search middlewares sparingly when generated links should preserve or transform inherited search state. Good cases:

- preserve a root-level locale or workspace search param
- strip temporary modal/search UI state from child links
- normalize search defaults before href generation

Do not use search middleware as a substitute for route-local `validateSearch`.

## Standard Schema

Standard Schema lets validation libraries plug into Router without adapters. Valibot, ArkType, and Effect Schema can be passed directly when they implement Standard Schema. Zod often uses `zodValidator` or Zod v4-compatible schema behavior depending on the version and desired input/output types.

Advice:

- If the project already uses Zod, keep Zod for consistency.
- If using Zod v3 and defaults/fallbacks lose inference, use `fallback` from `@tanstack/zod-adapter`.
- If using Valibot/ArkType/Effect Schema, prefer direct Standard Schema usage when supported.
- Model search params with defaults so links do not require noisy `search` objects everywhere.

## Search-Driven Query Keys

When search affects data, include validated search in the query key through `loaderDeps`:

```tsx
const projectsQuery = (filters: { page: number; q: string; sort: string }) =>
  queryOptions({
    queryKey: ['projects', filters],
    queryFn: () => listProjects({ data: filters }),
  })
```

Avoid deriving query keys from raw `location.search`. Use validated route search.

## Serious-App Pattern

For complex pages:

- path params identify resources
- search params model view state: filters, sorting, tabs, pagination, drawer IDs
- route context carries dependencies and auth/tenant facts
- loaders coordinate data before render
- TanStack Query owns server state cache
- components read route/search/params from typed route APIs

This combination is the TanStack way to keep serious React apps predictable.
