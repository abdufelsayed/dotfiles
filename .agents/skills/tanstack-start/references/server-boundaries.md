# Server Boundaries, SSR, And Runtime Safety

TanStack Start is isomorphic by default. Code in routes can run on both server and client unless you explicitly put it behind a Start boundary.

## Execution Model

- Initial request: matching routes can run `beforeLoad`, loaders, and render on the server.
- Client navigation: `beforeLoad` and loaders run on the client.
- Server functions: handler code runs on the server, but functions can be called from loaders/components/events.
- Server routes: HTTP endpoints handled on the server.

Do not assume a route loader is server-only.

## Server Functions

Use `createServerFn` for typed RPC between client and server:

```tsx
export const getProject = createServerFn({ method: 'GET' })
  .inputValidator(z.object({ projectId: z.string() }))
  .handler(async ({ data }) => {
    return db.projects.findById(data.projectId)
  })
```

Use:

- `GET` for reads
- `POST` for mutations
- `inputValidator` for all untrusted input
- server middleware for auth/authorization
- `redirect` and `notFound` for route-aware failures

## Server Routes

Use server routes when the thing needs a URL:

- webhook
- OAuth callback
- file upload/download
- custom HTTP cache headers
- third-party/mobile caller
- raw Request/Response handling

```tsx
export const Route = createFileRoute('/api/health')({
  server: {
    handlers: {
      GET: () => Response.json({ ok: true }),
    },
  },
})
```

## Environment Functions

Use environment helpers to keep code honest:

```tsx
const readSecret = createServerOnlyFn(() => process.env.API_SECRET)

const readLocalStorage = createClientOnlyFn(() =>
  window.localStorage.getItem('theme'),
)

const log = createIsomorphicFn()
  .server((msg: string) => console.log('[server]', msg))
  .client((msg: string) => console.log('[client]', msg))
```

Prefer these over scattered `typeof window` checks when the environment boundary matters.

## Import Protection

Start has import protection enabled by default.

Use file suffixes:

- `*.server.ts`: denied from client bundles
- `*.client.ts`: denied from server bundles

Use marker imports when a file cannot be renamed:

```ts
import '@tanstack/react-start/server-only'
```

```ts
import '@tanstack/react-start/client-only'
```

Type-only imports are safe because they erase at runtime. Mixed imports with runtime values are not safe.

Avoid mixed barrels that re-export server-only and client-safe code from the same entrypoint. Split entrypoints:

```ts
// src/lib/index.ts
export { publicHelper } from './public-helper'

// src/lib/server.ts
export { getDb } from './db.server'
```

## Env Vars

Rules:

- Client-safe vars use `import.meta.env.VITE_*`.
- Server secrets use `process.env` inside server functions, middleware, server routes, or `createServerOnlyFn`.
- Do not read secrets at module scope in shared/client-reachable modules.
- On Worker/edge runtimes, env may be request-scoped. Read per request.

Bad:

```ts
const apiKey = process.env.SECRET_KEY
```

Good:

```ts
const getApiKey = createServerOnlyFn(() => process.env.SECRET_KEY)
```

or:

```tsx
const fetchData = createServerFn().handler(async () => {
  const apiKey = process.env.SECRET_KEY
  return callService(apiKey)
})
```

## SSR Modes

Route `ssr` controls initial server request behavior:

- `true`: default. Run `beforeLoad`, loader, and render component on server.
- `false`: do not run `beforeLoad`/loader or render component on server for that route.
- `'data-only'`: run `beforeLoad`/loader on server but do not server-render component.
- function form: decide on the server based on validated params/search.

Parent routes can make child routes more restrictive. A child cannot re-enable server behavior disabled by a parent.

Use selective SSR for browser-only components, canvas, localStorage-dependent UI, or data-only shells.

SPA mode disables server-side route execution and rendering more broadly. Prefer selective SSR when only some routes need it.

## Static And Cache Patterns

Use prerendering for static routes and static marketing/docs pages. Dynamic routes can be discovered by crawling links or configured manually.

Use HTTP cache headers for ISR-style behavior:

```tsx
export const Route = createFileRoute('/blog/$slug')({
  loader: ({ params }) => fetchPost(params.slug),
  headers: () => ({
    'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
  }),
})
```

Never use public cache headers for user-specific or tenant-specific responses. Use `private` or `no-store`.

## Hydration Safety

Hydration errors usually come from server/client output mismatch:

- `Date.now()`
- random IDs
- locale/time zone differences
- responsive-only logic
- localStorage preferences
- feature flags that differ server/client

Fix by making server/client render deterministic, moving browser-only work to effects/client-only functions, or using selective SSR/data-only for truly browser-only routes.

## Red Flags

- route loader imports `fs`, DB client, or secret directly
- module-level `process.env.SECRET`
- shared barrel exports both server and client modules
- client component calls unprotected server function
- public `Cache-Control` on personalized data
- manual `typeof window` everywhere instead of a clear environment function
