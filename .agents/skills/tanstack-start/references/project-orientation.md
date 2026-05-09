# Project Orientation

Use this when reviewing an existing TanStack Start React app before recommending patterns or changing code.

## Files To Inspect

- `package.json`: confirm `@tanstack/react-start`, `@tanstack/react-router`, `@vitejs/plugin-react`, `vite`, validation libraries, `@tanstack/react-query`, and `@tanstack/react-router-ssr-query`.
- `vite.config.ts`: confirm `tanstackStart()` plugin, React plugin, path aliases, prerender/SSR/import protection settings, and hosting plugins.
- `src/router.tsx`: confirm `getRouter()` returns a fresh router and whether router context includes `queryClient`, auth, services, or app config.
- `src/routes/__root.tsx`: root document shell, `HeadContent`, `Scripts`, global meta, default layout, `createRootRouteWithContext`.
- `src/routeTree.gen.ts`: generated file. Do not edit manually.
- `src/start.ts`: optional Start-level config such as global `requestMiddleware`, `functionMiddleware`, `defaultSsr`.
- `src/server.ts`: optional custom server entry.
- `src/client.tsx`: optional custom client entry.
- `src/routes/**`: file route conventions, pathless layouts, auth layouts, server route handlers, loaders, search validation.
- `src/**/*.server.*`, `src/**/*.client.*`, marker imports: environment boundaries.

## Questions To Answer From The Code

- Is this a Start app or only TanStack Router?
- Does `router.tsx` create a new `QueryClient` per router instance?
- Is `setupRouterSsrQueryIntegration` installed when TanStack Query is used?
- Are route loaders returning data directly, warming Query cache, or both?
- Are search params validated with a schema or just cast?
- Are auth route guards paired with handler-level server checks?
- Are server functions using `inputValidator` for untrusted input?
- Are secrets, DB clients, cookies, and request headers read in server-only places?
- Are route params/search values included in query keys when they affect data?
- Are mutation success handlers invalidating Query cache and/or router state?

## Common App Shapes

### Router Cache Only

Good for smaller apps with route-local data and coarse invalidation. Loaders return data and components use `Route.useLoaderData()`.

### TanStack Query App

Best for serious apps with shared server state, mutations, background refetching, optimistic updates, and cross-route reuse. Loaders usually call `context.queryClient.ensureQueryData(...)`; components read the same query with `useSuspenseQuery(...)`.

### Authenticated Layout App

Protected pages live under a pathless route such as `/_authenticated`. Its `beforeLoad` verifies session and returns typed context for children. Protected server functions and server routes still enforce auth independently.

### External API Or BFF App

Start server functions/server routes act as a typed BFF in front of an external API. This is useful when the browser should not see API secrets, raw cookies, or backend topology.

## Review Output

When advising, lead with:

- what pattern the app currently uses
- whether it matches the user goal
- risks or missing boundaries
- the smallest TanStack-native next step

Keep implementation details behind references unless the user asks for code.
