# Debugging And Testing

Use this when diagnosing a TanStack Start app or choosing verification steps after changes.

## Fast Triage

First classify the issue:

- route not generated
- route match/navigation problem
- search validation/type problem
- loader/query data problem
- server function/server route problem
- auth/session problem
- hydration/client-only problem
- deployment/runtime problem

Then inspect the smallest relevant files before changing code.

## Route Generation Problems

Symptoms:

- `Route` type missing
- link `to` path rejected
- `routeTree.gen.ts` lacks a route
- route component never renders

Check:

- file is under `src/routes`
- file exports `Route`
- `createFileRoute('/path')` path matches file convention
- parent route exists when using nested files
- route file is not ignored by prefix
- generated `routeTree.gen.ts` is not manually edited
- dev/build/typecheck has refreshed typegen

## Search Param Problems

Symptoms:

- invalid search params crash route
- `search` type is `any` or too loose
- filters reset unexpectedly
- links drop parent search params

Check:

- `validateSearch` exists at the route boundary
- schema defaults/fallbacks are used
- `loaderDeps` includes search values that affect loader data
- navigation uses functional `search`
- parent search inheritance is intentional
- search middleware is not hiding a validation bug

## Loader And Query Problems

Symptoms:

- duplicate requests
- stale list after mutation
- SSR fetch works but client navigation fails
- client bundle tries to import DB/secrets

Check:

- whether loader fetch is direct or warms Query
- query key contains params/search/tenant dimensions
- `QueryClient` is created per router instance
- `setupRouterSsrQueryIntegration` is installed
- protected query functions enforce auth server-side
- server-only work is behind `createServerFn` or server-only files
- mutation invalidates Query and Router when needed

## Server Function Problems

Symptoms:

- handler cannot read cookies/headers
- client receives unserializable data
- action works unauthenticated
- `process.env` leaks or fails in client

Check:

- method is correct: `GET` for reads, `POST` for mutations
- `inputValidator` exists
- auth middleware is attached
- response data is serializable
- DB/secrets are imported only in server-safe modules
- runtime supports the APIs used

## Auth Problems

Symptoms:

- protected page redirects but data endpoint still leaks
- login redirect loops
- user context missing in child routes
- session exists in browser but server function says unauthenticated

Check:

- private pages are under a pathless auth route
- auth route `beforeLoad` returns context for children
- protected server functions use auth middleware
- protected server routes use request middleware or handler checks
- cookie flags and path/domain are correct
- redirects preserve a safe same-origin target
- login/logout mutations use `POST`, not `GET`

## Hydration Problems

Symptoms:

- hydration mismatch warning
- page flashes wrong theme/auth state
- server HTML differs from client render

Common causes:

- `Date.now()` or random values during render
- localStorage/theme reads during render
- locale/time zone differences
- browser-only APIs in SSR route components
- feature flags differ between server and client
- data unavailable server-side but available client-side

Fixes:

- make render deterministic
- move browser-only reads into effects or client-only functions
- pass server-known values through route context/loader
- use `ssr: false` or `ssr: 'data-only'` only when appropriate

## Verification Commands

Use the project's scripts. Common checks:

```bash
pnpm typecheck
pnpm test
pnpm build
pnpm lint
```

or equivalent `npm`, `bun`, or `yarn` commands.

For routing/typegen issues, build or dev startup is often more meaningful than isolated TypeScript.

## Testing Patterns

Unit test:

- pure validation schemas
- query option key factories
- server-only business functions
- auth/session helpers

Integration test:

- server function input/auth behavior
- server route HTTP behavior
- route loader behavior with mocked server functions

Browser/E2E test:

- login redirect flow
- search param filters/pagination
- mutation + invalidation UX
- protected route navigation
- modal routes or route masking

## Review Response Shape

When reporting a debug finding:

- symptom
- likely boundary involved
- files inspected
- root cause
- minimal fix
- verification command
