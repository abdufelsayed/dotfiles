# Auth With TanStack Start Primitives

Focus on TanStack Start primitives, not provider SDKs: route `beforeLoad`, pathless layouts, server functions, middleware, server routes, cookies, and trusted server context.

## Core Rule

Auth has two halves:

- Routing half: protect page experience and redirect or render login.
- Server half: protect data/actions/endpoints.

A route guard does not protect a `createServerFn`. Server functions are RPC endpoints and can be called directly. Every protected server function or server route must enforce auth on the server.

## Recommended Shape

Use a pathless authenticated layout for protected pages:

```tsx
// src/routes/_authenticated.tsx
import { Outlet, createFileRoute, redirect } from '@tanstack/react-router'
import { getCurrentUser } from '~/server/auth.functions'

export const Route = createFileRoute('/_authenticated')({
  beforeLoad: async ({ location }) => {
    const user = await getCurrentUser()

    if (!user) {
      throw redirect({
        to: '/login',
        search: { redirect: location.href },
      })
    }

    return { auth: { userId: user.id, role: user.role } }
  },
  component: () => <Outlet />,
})
```

Child routes can read the typed context in loaders:

```tsx
export const Route = createFileRoute('/_authenticated/dashboard')({
  loader: ({ context }) => {
    return context.queryClient.ensureQueryData(
      dashboardQuery(context.auth.userId),
    )
  },
})
```

Still enforce server-side auth in `dashboardQuery`'s server function.

## Session Lookup

Prefer HTTP-only cookie sessions for traditional Start apps. Use an opaque session ID backed by a DB when revocation matters.

Read cookies per request, not at module scope:

```tsx
// src/server/session.ts
import { getRequestHeader, setResponseHeader } from '@tanstack/react-start/server'

const SESSION_COOKIE = '__Host-session'

export function readSessionToken() {
  const cookie = getRequestHeader('cookie')
  if (!cookie) return null

  for (const part of cookie.split(/;\s*/)) {
    const eq = part.indexOf('=')
    if (eq === -1) continue
    if (part.slice(0, eq) === SESSION_COOKIE) return part.slice(eq + 1)
  }

  return null
}

export function setSessionCookie(token: string) {
  setResponseHeader(
    'Set-Cookie',
    [
      `${SESSION_COOKIE}=${token}`,
      'HttpOnly',
      'Secure',
      'SameSite=Lax',
      'Path=/',
      'Max-Age=86400',
    ].join('; '),
  )
}
```

Cookie flags:

- `HttpOnly`: browser JS cannot read the cookie.
- `Secure`: HTTPS only and required for `__Host-`.
- `SameSite=Lax`: blocks most cross-site POST CSRF.
- `__Host-`: exact-origin cookie, no `Domain`, `Path=/`, `Secure`.
- `Max-Age`: bounded lifetime, ideally with server-side rotation.

## Server Function Auth Middleware

Use function middleware for protected server functions:

```tsx
// src/server/auth-middleware.ts
import { createMiddleware } from '@tanstack/react-start'
import { readSessionToken } from './session'

export const authMiddleware = createMiddleware({ type: 'function' }).server(
  async ({ next }) => {
    const token = readSessionToken()
    const session = token ? await db.sessions.findValid(token) : null

    if (!session) throw new Error('Unauthorized')

    return next({ context: { session } })
  },
)
```

Attach it to every protected function:

```tsx
export const getMyProjects = createServerFn({ method: 'GET' })
  .middleware([authMiddleware])
  .handler(async ({ context }) => {
    return db.projects.findMany({
      where: { userId: context.session.userId },
    })
  })
```

For authorization, add checks after authentication:

```tsx
export const requireProjectMember = createMiddleware({ type: 'function' })
  .middleware([authMiddleware])
  .inputValidator(z.object({ projectId: z.string() }))
  .server(async ({ data, context, next }) => {
    const member = await db.memberships.find({
      userId: context.session.userId,
      projectId: data.projectId,
    })

    if (!member) throw new Error('Forbidden')

    return next({ context: { member } })
  })
```

## Request Middleware Vs Function Middleware

Use request middleware for:

- SSR request decoration
- server routes
- global request logging
- CSP/security headers
- locale/time zone context

Use function middleware for:

- `createServerFn`
- input validation before the function handler
- client and server middleware hooks
- typed function context

Global middleware belongs in `src/start.ts`:

```tsx
import { createStart } from '@tanstack/react-start'
import { requestLogger, authFunctionMiddleware } from './server/middleware'

export const startInstance = createStart(() => ({
  requestMiddleware: [requestLogger],
  functionMiddleware: [authFunctionMiddleware],
}))
```

Use global function middleware carefully. If some functions are public, either make the middleware optional/public-aware or attach auth per function.

## Server Routes

Use server routes for external HTTP edges: webhooks, OAuth callbacks, file uploads, third-party APIs, or mobile/third-party clients.

```tsx
export const Route = createFileRoute('/api/projects/$projectId')({
  server: {
    middleware: [requestAuthMiddleware],
    handlers: {
      GET: async ({ params, context }) => {
        const project = await db.projects.findAuthorized({
          projectId: params.projectId,
          userId: context.session.userId,
        })
        return Response.json({ project })
      },
    },
  },
})
```

Server routes need request middleware, not function middleware.

## Login And Logout

Login is a `POST` server function:

- validate email/password
- use constant-time-ish behavior for user-not-found vs wrong-password
- issue session
- set HTTP-only cookie
- redirect or return success

Logout:

- clear server session
- clear cookie
- redirect or return success

Never mutate auth state through GET.

## CSRF And Origin Checks

SameSite=Lax helps but is not the whole story.

Rules:

- no GET mutation
- validate Origin for non-GET credentialed requests, especially sibling subdomains
- rate-limit login, signup, reset, and token exchange endpoints
- return uniform password reset responses to avoid account enumeration

## Context Trust Boundaries

- Route params and search are user input.
- Route context can help page decisions but is not a security boundary by itself.
- Client-sent middleware context is untrusted.
- Server function context produced by server middleware is trusted only if derived from server sources such as cookies and DB lookup.
- Tenant/workspace IDs from params/search must be checked against the authenticated session server-side.

## Common Auth Patterns

### Protected App Shell

`/_authenticated.tsx` loads user and returns auth context. All private routes live below it.

### Public Login Redirect

Protected route redirects to `/login?redirect=<current href>`. After login, use the validated redirect target carefully. Only allow same-origin app paths.

### Optional Auth

Use a public `getCurrentUser` server function that returns `null` if absent. Good for nav bars and mixed public/private pages. Protected actions still use `authMiddleware`.

### External Cookie API

If Start talks to a separate backend that owns cookies, use server functions as a BFF. Forward trusted cookies from the Start request on the server, or call a `/me` endpoint server-side. Do not expose backend secrets to the browser.

## Red Flags

- `beforeLoad` is the only auth check for private data.
- DB/client secret is imported into a route loader directly.
- `context.userId` came from client-sent context.
- server functions accept raw params without `inputValidator`.
- route params are used for tenant access without membership checks.
- auth state is only a React context hook and route code cannot access it.
