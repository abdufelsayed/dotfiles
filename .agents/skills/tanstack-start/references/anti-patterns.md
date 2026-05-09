# Anti-Patterns

Use this as a quick review guide for common TanStack Start mistakes.

## Treating Loaders As Server-Only

Bad:

```tsx
loader: () => db.project.findMany()
```

Why: loaders can run on the client during navigation.

Use:

- `createServerFn`
- `*.server.ts`
- `createServerOnlyFn`
- server routes for HTTP endpoints

## Duplicating Router Data And Query Data

Bad:

- loader returns the full list
- component also calls `useQuery` for the same list
- mutation invalidates only one cache

Use one ownership model. For serious server state, let TanStack Query own the data and let loaders warm Query.

## Untyped Search Params

Bad:

```tsx
const page = Number(new URLSearchParams(location.search).get('page') ?? 1)
```

Use `validateSearch`, `loaderDeps`, and typed navigation.

## Manual URL String Building

Bad:

```tsx
navigate({ to: `/orgs/${orgId}/projects/${projectId}?tab=settings` })
```

Use typed `to`, `params`, and `search`.

## Route Guard As The Only Auth Check

Bad:

- `_authenticated.beforeLoad` redirects unauthenticated users
- page calls public server function that returns private data

Use both:

- route guard for page UX
- server function/server route auth for data and actions

## Client-Sent Context As Trusted Auth

Bad:

```tsx
context: { userId: localStorage.getItem('userId') }
```

Use server-derived session context from cookies/DB in server middleware.

## Mixed Server/Client Barrels

Bad:

```ts
export * from './db.server'
export * from './format'
```

Split server-only exports from client-safe exports.

## Public Cache For Personalized HTML

Bad:

```tsx
headers: () => ({
  'Cache-Control': 'public, s-maxage=3600',
})
```

on a dashboard or tenant page.

Use `private, no-store` for user-specific responses.

## Global QueryClient In SSR

Bad:

```tsx
const queryClient = new QueryClient()
```

at module scope for a Start SSR app.

Create the `QueryClient` inside `getRouter()` so each router/request has isolated cache state.

## Skipping Input Validation

Bad:

```tsx
export const updateProject = createServerFn({ method: 'POST' }).handler(...)
```

Use `inputValidator`, then enforce auth/authorization in middleware or handler.

## Using GET For Mutations

Bad:

- logout via GET
- delete via GET
- update via GET

Use `POST` server functions or server routes for mutations.

## Fixing Hydration By Disabling SSR Everywhere

Bad:

- set the whole app to SPA mode because one widget uses `window`

Use:

- deterministic render
- client-only functions
- route-level `ssr: false`
- `ssr: 'data-only'` for browser-only components with server data
