# Source Index

Use these sources when answering TanStack Start questions. Prefer current official docs first, then examples, then community signals.

## Official TanStack Start

- Overview: https://tanstack.com/start/latest/docs/framework/react/overview
- Getting Started: https://tanstack.com/start/latest/docs/framework/react/getting-started
- Build From Scratch: https://tanstack.com/start/latest/docs/framework/react/build-from-scratch
- Routing: https://tanstack.com/start/latest/docs/framework/react/guide/routing
- Execution Model: https://tanstack.com/start/latest/docs/framework/react/guide/execution-model
- Code Execution Patterns: https://tanstack.com/start/latest/docs/framework/react/guide/code-execution-patterns
- Import Protection: https://tanstack.com/start/latest/docs/framework/react/guide/import-protection
- Environment Variables: https://tanstack.com/start/latest/docs/framework/react/guide/environment-variables
- Server Functions: https://tanstack.com/start/latest/docs/framework/react/guide/server-functions
- Middleware: https://tanstack.com/start/latest/docs/framework/react/guide/middleware
- Server Routes: https://tanstack.com/start/latest/docs/framework/react/guide/server-routes
- Authentication Overview: https://tanstack.com/start/latest/docs/framework/react/guide/authentication-overview
- Authentication: https://tanstack.com/start/latest/docs/framework/react/guide/authentication
- Authentication Server Primitives: https://tanstack.com/start/v0/docs/framework/react/guide/authentication-server-primitives
- Selective SSR: https://tanstack.com/start/latest/docs/framework/react/guide/selective-ssr
- Static Prerendering: https://tanstack.com/start/latest/docs/framework/react/guide/static-prerendering
- ISR: https://tanstack.com/start/latest/docs/framework/react/guide/isr
- Hosting: https://tanstack.com/start/latest/docs/framework/react/guide/hosting

## Official TanStack Router

Start relies on Router. Use Router docs for route mechanics.

- File-based routing: https://tanstack.com/router/latest/docs/routing/file-based-routing
- File naming conventions: https://tanstack.com/router/latest/docs/routing/file-naming-conventions
- Path params: https://tanstack.com/router/latest/docs/guide/path-params
- Search params: https://tanstack.com/router/latest/docs/guide/search-params
- Data loading: https://tanstack.com/router/latest/docs/guide/data-loading
- Router context: https://tanstack.com/router/latest/docs/guide/router-context
- Authenticated routes: https://tanstack.com/router/latest/docs/guide/authenticated-routes
- Type safety: https://tanstack.com/router/latest/docs/guide/type-safety
- TanStack Query integration: https://tanstack.com/router/latest/docs/integrations/query

## Official Examples

- Basic Start: https://github.com/TanStack/router/tree/main/examples/react/start-basic
- Basic + React Query: https://github.com/TanStack/router/tree/main/examples/react/start-basic-react-query
- Basic + DIY Auth: https://github.com/TanStack/router/tree/main/examples/react/start-basic-auth
- Basic + Static Rendering: https://github.com/TanStack/router/tree/main/examples/react/start-basic-static
- Convex Trellaux: https://github.com/TanStack/router/tree/main/examples/react/start-convex-trellaux

## Community Signals

Use community content as a source of practical questions and edge cases, not as final authority. Verify against official docs and working code.

Patterns seen repeatedly in community discussion:

- Use a pathless authenticated layout plus `beforeLoad` for protected page UX.
- Pair route guards with server function or server route auth checks.
- Use server functions as a BFF when an external API owns cookie/session state.
- With TanStack Query, loaders should warm the cache and components should read via Query hooks.
- For SSR confusion, remember loaders are isomorphic and server functions are the server-only boundary.

When community examples use auth providers, extract only the Start/Router pattern unless the user asks for that provider.
