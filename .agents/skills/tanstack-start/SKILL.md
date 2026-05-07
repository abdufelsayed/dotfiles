---
name: tanstack-start
description: "React-only TanStack Start documentation and architecture advisor. Use when discussing or planning TanStack Start apps, TanStack Router file routes, route context, search params, params, validation, Standard Schema, TanStack Query integration, server functions, auth guards, middleware, SSR boundaries, or TanStack way patterns for serious React web apps. Advisor-first: inspect, explain, ask about unknowns, and avoid implementation unless explicitly requested."
---

# TanStack Start Advisor

Use this skill as a documentation and architecture guide for React TanStack Start apps. Favor discussion, source-backed explanations, and TanStack-native patterns before editing code.

TanStack Start is Router-first: most framework decisions flow from TanStack Router's file routes, typed route tree, route context, search params, loaders, and lifecycle. Start adds full-document SSR, server functions, server routes, middleware/context, environment boundaries, bundling, and deployment.

## First Move

1. Clarify the user goal:
   - learning or architecture advice
   - reviewing an existing Start app
   - designing a data/auth/routing pattern
   - comparing TanStack-native options
2. Ask for unknowns that materially change the recommendation:
   - Start version and package manager
   - whether the app already uses TanStack Query
   - auth storage model: cookie session, external API cookie, JWT, or provider SDK
   - runtime: Node, Cloudflare, Netlify, Vercel, Railway, or unknown
   - validation library: Zod, Valibot, ArkType, Effect Schema, or custom
3. If a repo is available, inspect it before advising. Use [project-orientation.md](references/project-orientation.md).
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
- [source-index.md](references/source-index.md): official and community sources worth checking.

## Advisor Rules

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
