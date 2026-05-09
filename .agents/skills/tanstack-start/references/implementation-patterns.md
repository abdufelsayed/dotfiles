# Implementation Patterns

Use this when working directly in a TanStack Start React codebase. Keep changes TanStack-native, local to the feature, and consistent with the app's existing conventions.

## First Inspect The App

Before editing, identify:

- package manager and scripts from `package.json`
- Start/Router/Query versions
- route style: flat file routes, directory routes, or mixed
- aliases: `~/`, `@/`, workspace packages, or relative imports
- validation library: Zod, Valibot, ArkType, Effect Schema, or local helpers
- data style: Router loader data, TanStack Query, or mixed
- auth style: cookie session, external API cookie, JWT, provider SDK, or none
- runtime/deploy target when server APIs or env handling are involved

Then make the smallest coherent change. Do not rewrite the routing structure just to add one route.

## Add TanStack Query To Start

Use when an app has shared server state, mutations, or cross-route cache needs.

1. Add dependencies if missing:
   - `@tanstack/react-query`
   - `@tanstack/react-router-ssr-query`
2. In `src/router.tsx`, create a new `QueryClient` inside `getRouter()`.
3. Pass `queryClient` through router context.
4. Call `setupRouterSsrQueryIntegration({ router, queryClient })`.
5. Register the router type with module augmentation.
6. Move route data fetches into query option factories.
7. Change route loaders to `ensureQueryData(...)`.
8. Change components to read with `useSuspenseQuery(...)` for route-critical data.

Good target shape:

```tsx
export function getRouter() {
  const queryClient = new QueryClient()

  const router = createRouter({
    routeTree,
    context: { queryClient },
    defaultPreload: 'intent',
  })

  setupRouterSsrQueryIntegration({ router, queryClient })

  return router
}
```

Avoid:

- module-level singleton `QueryClient` for SSR apps
- loader returns one copy of data while Query owns another copy
- query keys missing params/search/auth dimensions

## Refactor A Loader To Query

Use this pattern when a route currently fetches directly in `loader`.

Before:

```tsx
loader: ({ params }) => fetchProject(params.projectId)
```

After:

```tsx
loader: ({ params, context }) =>
  context.queryClient.ensureQueryData(projectQuery(params.projectId))
```

Component:

```tsx
function ProjectPage() {
  const { projectId } = Route.useParams()
  const project = useSuspenseQuery(projectQuery(projectId))
  return <ProjectView project={project.data} />
}
```

Keep `Route.useLoaderData()` for route-local metadata if useful, but do not duplicate server state by habit.

## Add Validated Search To A List Page

Use search params for list state: filters, sorting, pagination, selected tab, open drawer ID, modal ID, view mode.

1. Define a schema near the route or in the feature module.
2. Add `validateSearch`.
3. Add `loaderDeps` that returns only the search pieces that affect loader data.
4. Use `Route.useSearch()` in the page.
5. Use `Route.useNavigate()` or `useNavigate({ from: Route.fullPath })` for updates.

Example:

```tsx
const projectSearchSchema = z.object({
  page: z.number().catch(1),
  q: z.string().catch(''),
  status: z.enum(['all', 'active', 'archived']).catch('all'),
})

export const Route = createFileRoute('/projects')({
  validateSearch: projectSearchSchema,
  loaderDeps: ({ search }) => ({
    page: search.page,
    q: search.q,
    status: search.status,
  }),
  loader: ({ deps, context }) =>
    context.queryClient.ensureQueryData(projectsQuery(deps)),
})
```

Search update:

```tsx
const navigate = Route.useNavigate()

navigate({
  search: (prev) => ({
    ...prev,
    q: nextQuery,
    page: 1,
  }),
})
```

Avoid:

- manual `new URLSearchParams(location.search)` in components
- stringly typed `page: Number(search.page) || 1`
- interpolating search or params into `to`
- losing existing search params when updating one filter

## Add A Protected App Section

Use a pathless layout route for private app pages.

Common file shape:

```text
src/routes/_authenticated.tsx
src/routes/_authenticated/index.tsx
src/routes/_authenticated/projects.tsx
```

Route guard:

```tsx
export const Route = createFileRoute('/_authenticated')({
  beforeLoad: async ({ location }) => {
    const user = await getCurrentUser()
    if (!user) {
      throw redirect({
        to: '/login',
        search: { redirect: location.href },
      })
    }

    return {
      auth: {
        userId: user.id,
        role: user.role,
      },
    }
  },
  component: AuthenticatedLayout,
})
```

Server protection still belongs in server functions and server routes:

```tsx
export const getPrivateProjects = createServerFn({ method: 'GET' })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return db.projects.forUser(context.session.userId)
  })
```

Check for this common bug during review: `beforeLoad` protects the page, but the server function used by the page is public.

## Add A Server Function

Use server functions for typed app RPC.

Checklist:

- choose `GET` for reads, `POST` for mutations
- validate input with `inputValidator`
- enforce auth/authorization in middleware or handler
- return serializable values
- keep DB/secrets in server-only modules
- call from query options, loaders, mutations, or event handlers

Read:

```tsx
export const getProject = createServerFn({ method: 'GET' })
  .middleware([authMiddleware])
  .inputValidator(z.object({ projectId: z.string() }))
  .handler(async ({ data, context }) => {
    return db.projects.findForUser(data.projectId, context.session.userId)
  })
```

Mutation:

```tsx
export const updateProject = createServerFn({ method: 'POST' })
  .middleware([authMiddleware])
  .inputValidator(updateProjectSchema)
  .handler(async ({ data, context }) => {
    return db.projects.updateForUser(data, context.session.userId)
  })
```

FormData is valid for POST server functions. Parse it in `inputValidator`, then pass a typed object to the handler.

## Add A Mutation Flow

Use TanStack Query for mutation state and cache invalidation.

```tsx
function useUpdateProject() {
  const queryClient = useQueryClient()
  const router = useRouter()

  return useMutation({
    mutationFn: (data: UpdateProjectInput) => updateProject({ data }),
    onSuccess: async (_, input) => {
      await queryClient.invalidateQueries({ queryKey: ['project', input.id] })
      await queryClient.invalidateQueries({ queryKey: ['projects'] })
      await router.invalidate()
    },
  })
}
```

Use `queryClient.invalidateQueries(...)` for Query-owned data. Use `router.invalidate()` when route loaders, route context, or `beforeLoad` decisions need to rerun. Use `router.invalidate({ sync: true })` when the UI must wait until loaders finish.

## Add A Server Route

Use server routes for real HTTP edges:

- webhooks
- OAuth callbacks
- file upload/download
- health checks
- mobile or third-party clients
- custom headers/status/cache behavior

```tsx
export const Route = createFileRoute('/api/projects/$projectId')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        const project = await getPublicProject(params.projectId)
        return Response.json({ project })
      },
    },
  },
})
```

For protected endpoints, use request middleware or handler-level checks. Function middleware is for `createServerFn`, not server routes.

## Clean Up Server Boundaries

When a route loader or component imports server-only logic:

1. Move DB/secret/filesystem access into `*.server.ts` or a server function.
2. Add `server-only` marker imports for sensitive modules that cannot be renamed.
3. Replace route loader direct calls with `createServerFn`.
4. Keep client-safe types in separate files or type-only imports.
5. Split barrels that re-export server-only and client-safe values together.

Bad:

```tsx
import { db } from '~/db'

loader: () => db.project.findMany()
```

Good:

```tsx
loader: () => listProjects()
```

where `listProjects` is a protected server function or server-only function.

## Add A New Route

Before adding a route:

- inspect neighboring route filenames
- use the same flat or directory convention
- decide whether it belongs under a layout/pathless route
- add `validateSearch` if it has URL state
- add `beforeLoad` if it gates access or enriches context
- add loader only for route-critical data
- set `head`/metadata when the route is indexable or user-facing
- add pending/error/not-found components when the route has meaningful failure states

After adding route files, run the project's route generation/typecheck/build command. In many projects this happens through Vite dev/build or a configured script.

## Review Checklist

Use this checklist during TanStack Start code review:

- route files follow local naming conventions
- generated route tree is not manually edited
- search params are validated and typed
- route params are treated as untrusted input
- loader data and Query cache are not duplicating the same server state
- query keys include params/search/tenant/auth dimensions
- mutations invalidate Query and/or Router intentionally
- protected pages and protected data endpoints both enforce auth
- server functions validate input and return serializable data
- DB/secrets/filesystem imports do not leak into client-reachable modules
- SSR mode choices are explicit for browser-only pages
- cache headers are not public for user-specific data
