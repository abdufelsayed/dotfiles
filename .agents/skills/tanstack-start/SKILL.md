---
name: tanstack-start
description: "React-only TanStack Start skill for building, reviewing, planning, and explaining TanStack Start apps. Use when working with TanStack Router file routes, route context, search params, params, validation, Standard Schema, TanStack Query integration, server functions, auth guards, middleware, SSR boundaries, or TanStack way patterns for serious React web apps."
---

# TanStack Start

Use this skill for React TanStack Start apps. It supports discussion, architecture, implementation, review, and debugging. Match the user's requested level of action: explain when they ask to understand, plan when they ask to design, and edit when they ask to change a codebase.

TanStack Start is Router-first: most framework decisions flow from TanStack Router's file routes, typed route tree, route context, search params, loaders, and lifecycle. Start adds full-document SSR, server functions, server routes, middleware/context, environment boundaries, bundling, and deployment.

## First Move

1. Clarify the user goal:
   - learning or architecture
   - reviewing an existing Start app
   - implementing a Start pattern
   - debugging a route/data/auth/server-boundary issue
   - designing a data/auth/routing pattern
   - comparing TanStack-native options
2. Ask for unknowns that materially change the recommendation:
   - Start version and package manager
   - whether the app already uses TanStack Query
   - auth storage model: cookie session, external API cookie, JWT, or provider SDK
   - runtime: Node, Cloudflare, Netlify, Vercel, Railway, or unknown
   - validation library: Zod, Valibot, ArkType, Effect Schema, or custom
3. If a repo is available, inspect it before recommending or changing patterns. Use [project-orientation.md](references/project-orientation.md).
4. If current docs or API stability matters, verify with official docs first. Start is RC-era and some areas move.

## Decision Map

- **Page/URL structure**: use file routes and route layouts. Read [routing-context.md](references/routing-context.md).
- **URL state**: use validated search params, not ad hoc `URLSearchParams`.
- **Typed dependencies**: use router context for request/app dependencies such as `queryClient`, auth snapshot, feature flags, tenant, or services.
- **Data read for route UI**: use route loaders. With TanStack Query, loaders warm the Query cache and components read with `useSuspenseQuery`.
- **Shared server state, mutations, optimistic updates, cross-route cache**: use TanStack Query. Read [query-data.md](references/query-data.md).
- **Sensitive server work**: use `createServerFn` plus server-side middleware or in-handler checks.
- **Public HTTP endpoint, webhook, third-party callback, file upload/download**: use server routes.
- **Auth for pages**: use route `beforeLoad` on a pathless/layout route.
- **Auth for data/actions**: enforce on each protected server function or server route. A route guard does not protect RPC endpoints.
- **Environment-specific code**: use server/client functions and import protection. Read [server-boundaries.md](references/server-boundaries.md).

## Reference Files

- [project-orientation.md](references/project-orientation.md): how to inspect a Start app and identify its patterns.
- [routing-context.md](references/routing-context.md): file routing, route context, params, search params, validation, Standard Schema, and lifecycle.
- [query-data.md](references/query-data.md): TanStack Query setup, SSR integration, loaders, query options, Suspense, streaming, mutations, and invalidation.
- [auth.md](references/auth.md): route guards, server function middleware, sessions, cookies, server route protection, CSRF, and auth context boundaries.
- [server-boundaries.md](references/server-boundaries.md): isomorphic execution, server/client-only APIs, env vars, import protection, SSR modes, hydration pitfalls.
- [implementation-patterns.md](references/implementation-patterns.md): practical recipes for adding or refactoring Start features in a codebase.
- [setup-config.md](references/setup-config.md): project setup, Vite config, entries, aliases, document shell, metadata, and route generation.
- [rendering-deployment.md](references/rendering-deployment.md): SSR choices, SPA mode, prerendering, ISR, cache headers, hosting, and deployment checks.
- [debugging-testing.md](references/debugging-testing.md): debugging route/data/auth issues, hydration errors, typegen problems, tests, and review commands.
- [anti-patterns.md](references/anti-patterns.md): common Start mistakes and the TanStack-native replacement patterns.
- [source-index.md](references/source-index.md): official and community sources worth checking.

## Operating Rules

- Stay React-only unless the user explicitly asks otherwise.
- Prefer official docs and official examples. Use community patterns as heuristics, then verify against Start/Router docs and working code.
- Explain the TanStack primitive choice, not just the code.
- Separate route context, React context, middleware context, and server function context. They solve different problems.
- Treat search params as typed state. Validate at the route boundary.
- Treat path params as user input. Parse/validate before business use when the format matters.
- Keep server trust boundaries explicit. Client-sent data, search params, route params, and client-sent context are untrusted.
- Do not recommend provider-specific auth as the default. Focus on Start primitives: route guards, middleware, cookies, server functions, and server routes.
- Do not assume loaders are server-only. Loaders run on the server for initial SSR and on the client during client navigation.
- Do not put secrets or DB calls directly in route loaders or client-reachable helpers. Put them behind server functions or server-only functions.
- When changing code, preserve the project's route naming style, package manager, validation library, aliases, UI primitives, and existing auth/session model.
- After changing route files, make sure generated route types are refreshed by the project's normal dev/build/typecheck flow.
