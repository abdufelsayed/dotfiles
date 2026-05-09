# Rendering, Caching, And Deployment

Use this when choosing SSR behavior, prerendering, caching, hosting, or deployment checks.

## Default Mental Model

TanStack Start supports full-document SSR by default. Route `beforeLoad`, loaders, and render can run on the server for the initial request. During client navigation, route code runs in the browser unless it calls server functions.

Choose rendering per route based on user value and runtime constraints.

## Route SSR Choices

Use route `ssr` when a route needs special behavior:

- `true`: default full SSR
- `false`: do not run route `beforeLoad`/loader or render component on server
- `'data-only'`: run `beforeLoad`/loader on server but skip server rendering the component
- function: choose based on server-side params/search/context

Use cases:

- browser-only canvas/editor: `ssr: false`
- route needs data priming but component is browser-only: `ssr: 'data-only'`
- public content page: default SSR or prerender
- private dashboard: default SSR, no public cache

## SPA Mode

SPA mode is broader than selective SSR. Use it when deploying a client-only app or when server-side route execution is not desired.

Prefer selective route SSR when only a small part of the app is browser-only. Do not switch the whole app to SPA mode just to fix one hydration bug.

## Static Prerendering

Prerender when pages are public and can be generated at build time:

- docs
- marketing pages
- blog index/static posts
- public product pages with known routes

Avoid prerender for:

- user-specific dashboards
- tenant-specific private pages
- pages requiring request cookies
- pages with per-request authorization

Check `vite.config.ts` for `tanstackStart({ prerender: ... })` and confirm route discovery matches the app's links or configured routes.

## ISR And Cache Headers

TanStack Start leans on standard HTTP caching. ISR-style behavior is usually controlled with `Cache-Control`.

Example:

```tsx
export const Route = createFileRoute('/blog/$slug')({
  loader: ({ params }) => getPublicPost(params.slug),
  headers: () => ({
    'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
  }),
})
```

Use `public` only for content safe to share between users. For authenticated or tenant-specific data:

```tsx
headers: () => ({
  'Cache-Control': 'private, no-store',
})
```

Do not cache HTML publicly when it contains user names, tenant data, auth state, or personalized navigation.

## Hosting Checklist

Before recommending deployment:

- identify runtime: Node, edge, serverless, static, Cloudflare, Netlify, Vercel, or custom
- verify server APIs used by the app exist in that runtime
- check environment variable access pattern
- check file system usage
- check streaming support if the app depends on it
- check cache headers and CDN behavior
- check upload/body size limits for server routes
- check cold start impact for DB clients

## Runtime-Specific Risks

Node:

- broadest compatibility
- easy DB driver support
- beware global mutable state shared between requests

Serverless:

- cold starts
- connection pooling
- request duration/body limits

Edge/Workers:

- no Node built-ins unless polyfilled
- request-scoped env bindings
- limited DB driver compatibility
- streaming and crypto APIs differ by platform

Static hosting:

- no server functions or server routes at runtime unless paired with separate backend
- use prerender or SPA mode intentionally

## Deployment Review Output

When reviewing deployment readiness, report:

- rendering mode per major route group
- server-only dependencies and runtime fit
- cache header risks
- env var risks
- auth/session cookie concerns
- recommended minimal verification command
