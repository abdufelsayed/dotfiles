# TanStack Query In TanStack Start

Use this when the app has shared server state, mutations, optimistic updates, background refetching, or data reused across routes. For serious apps, TanStack Query is usually the right cache and mutation layer.

## Required Setup

Install `@tanstack/react-query` and `@tanstack/react-router-ssr-query`.

In Start, `getRouter()` must create a fresh `QueryClient` per router instance, especially for SSR:

```tsx
// src/router.tsx
import { QueryClient } from '@tanstack/react-query'
import { createRouter } from '@tanstack/react-router'
import { setupRouterSsrQueryIntegration } from '@tanstack/react-router-ssr-query'
import { routeTree } from './routeTree.gen'

export function getRouter() {
  const queryClient = new QueryClient()

  const router = createRouter({
    routeTree,
    context: { queryClient },
    defaultPreload: 'intent',
    scrollRestoration: true,
  })

  setupRouterSsrQueryIntegration({
    router,
    queryClient,
  })

  return router
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof getRouter>
  }
}
```

What this gives:

- SSR dehydration/hydration for the Query cache
- streaming of queries resolved during initial server render
- redirect handling for redirects thrown from queries/mutations
- optional QueryClientProvider wrapping

## Query Options Pattern

Colocate query factories with the feature or server function. Always put params/search/auth-relevant dimensions in the key.

```tsx
import { queryOptions } from '@tanstack/react-query'
import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'

const listProjectsInput = z.object({
  orgId: z.string(),
  page: z.number(),
  q: z.string(),
})

export const listProjects = createServerFn({ method: 'GET' })
  .inputValidator(listProjectsInput)
  .handler(async ({ data }) => {
    return db.projects.list(data)
  })

export const projectsQuery = (input: z.infer<typeof listProjectsInput>) =>
  queryOptions({
    queryKey: ['projects', input],
    queryFn: () => listProjects({ data: input }),
    staleTime: 30_000,
  })
```

## Loader Warms Cache, Component Reads Query

This is the main Start + Query pattern:

```tsx
export const Route = createFileRoute('/orgs/$orgId/projects')({
  validateSearch: projectSearchSchema,
  loaderDeps: ({ search }) => search,
  loader: ({ params, deps, context }) => {
    return context.queryClient.ensureQueryData(
      projectsQuery({ orgId: params.orgId, ...deps }),
    )
  },
  component: ProjectsPage,
})

function ProjectsPage() {
  const { orgId } = Route.useParams()
  const search = Route.useSearch()
  const query = useSuspenseQuery(projectsQuery({ orgId, ...search }))

  return <ProjectsTable rows={query.data.items} />
}
```

Why:

- loader starts data work before render
- Query owns cache identity and reuse
- component stays reactive to background refetches
- SSR can stream/dehydrate data

## `useSuspenseQuery` Vs `useQuery`

Prefer `useSuspenseQuery` for route-critical data when the loader has ensured or fetched it. Use route pending/error boundaries for a clean UX.

Use `useQuery` when:

- data is optional or below the fold
- you need `enabled`
- you want non-Suspense loading states
- the query should start only after a client interaction

## `ensureQueryData`, `fetchQuery`, `prefetchQuery`

- `ensureQueryData`: return cached data if present, otherwise fetch. Good for route loaders that want data available before render without refetching every navigation.
- `fetchQuery`: fetch if stale according to query options. Use when the route must force freshness.
- `prefetchQuery`: start filling cache and ignore returned data. Good for warmup.
- Fire-and-forget `context.queryClient.fetchQuery(...)` in a loader can start a query for streaming without blocking SSR, but do not return or await the promise.

Blocking route data:

```tsx
loader: ({ context, params }) =>
  context.queryClient.ensureQueryData(projectQuery(params.projectId))
```

Streaming warmup:

```tsx
loader: ({ context, params }) => {
  context.queryClient.fetchQuery(projectActivityQuery(params.projectId))
}
```

## Router Cache Vs Query Cache

Use Router cache when data is route-local and simple. Use Query when:

- multiple routes/components use the same server state
- mutations need fine-grained invalidation
- optimistic updates matter
- background refetching matters
- cache keys are richer than one route match
- list/detail data should stay coherent

Do not keep the same server state in both caches unless there is a clear reason. If Query owns the data, loaders should warm Query and components should read Query.

## Mutations

Use server functions for mutations and TanStack Query for mutation state/invalidation.

```tsx
export const updateProject = createServerFn({ method: 'POST' })
  .middleware([authMiddleware])
  .inputValidator(updateProjectSchema)
  .handler(async ({ data, context }) => {
    return db.projects.update({
      ...data,
      userId: context.session.userId,
    })
  })

function useUpdateProject() {
  const queryClient = useQueryClient()
  const router = useRouter()

  return useMutation({
    mutationFn: (data: UpdateProjectInput) => updateProject({ data }),
    onSuccess: async (_, input) => {
      await queryClient.invalidateQueries({ queryKey: ['projects'] })
      await queryClient.invalidateQueries({ queryKey: ['project', input.id] })
      router.invalidate()
    },
  })
}
```

Use `router.invalidate()` when route loaders or `beforeLoad` context also need to rerun. Use `queryClient.invalidateQueries()` for Query-owned server state.

## Auth And Query

Auth-sensitive queries must call server functions that enforce auth. Do not rely on a protected route to secure the query.

Good:

- route guard checks page access for UX
- query function calls protected server function
- protected server function uses auth middleware

Bad:

- route guard checks auth
- query function calls unguarded RPC that returns private data

## Practical Defaults

- Create query option factories.
- Use object query keys with validated params/search.
- Use `useSuspenseQuery` for page-critical data.
- Use `staleTime` intentionally; do not leave all serious route data at accidental defaults.
- Keep mutations in feature hooks and server functions in feature/server modules.
- After mutation, invalidate by feature key and rerun router when route context/search/loaders depend on the changed facts.
