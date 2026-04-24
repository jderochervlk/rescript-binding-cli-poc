# Publish OAuth Design

**Date:** 2026-04-24
**Status:** Approved for planning
**Scope:** `rescript binding publish` authentication slice only

## Goal

Implement the first working authenticated publish milestone for the registry CLI by replacing the earlier `cloudflared` assumption with Cloudflare Access Managed OAuth.

For this slice, success means:

- `rescript binding publish` can complete an interactive browser login
- the CLI caches OAuth tokens in a user-level directory
- the CLI reuses cached tokens when possible
- the CLI successfully calls protected `GET /v1/me`

This slice does **not** include upload persistence, D1 allowlist enforcement, or the full publish flow.

## Context

The current project plan assumes contributors authenticate out-of-band with:

```bash
cloudflared access login https://publish.bindings.rescript-lang.org
```

That assumption should be replaced. Cloudflare Access Managed OAuth now supports interactive CLI authentication for self-hosted apps, which is a better fit for a new project.

The current codebase also only scaffolds `publish`; it does not yet perform real authenticated network calls.

## User Decisions

The following decisions were confirmed during design:

- `publish` should handle login automatically
- publisher identity remains keyed by GitHub login
- v1 may assume the developer has a browser installed
- auth should be cached in a user-level location, not the repo
- this slice is done when authenticated `GET /v1/me` works

## Architecture

### Cloudflare

Keep the configured publish hostname as a Cloudflare Access self-hosted app in front of the Worker custom domain. The default planned hostname is `publish.bindings.rescript-lang.org`.

Configure the app as follows:

- GitHub is the only identity provider in v1
- an Access `Allow` policy admits the intended publishers
- Managed OAuth is enabled
- dynamic client registration is enabled
- localhost redirect clients are allowed
- loopback redirect clients are allowed

Recommended OAuth grant settings:

- access token lifetime: `15m`
- grant session duration: `30d`

The public read hostname remains outside Access for this slice.

### CLI

`rescript binding publish` remains the only user-facing entrypoint for auth in v1.

The CLI is split into two layers:

1. ReScript command orchestration
2. a narrow JavaScript OAuth helper module

The ReScript layer owns command flow, messaging, and deciding when auth runs. The JavaScript helper owns the mechanics that are awkward in ReScript today:

- PKCE generation
- loopback callback listener
- browser launch
- token exchange
- refresh flow
- token cache file IO

This keeps the CLI flow in the existing language while minimizing Node-specific bindings.

### Worker

The Worker remains behind Cloudflare Access and does not become an OAuth server.

For this slice, the Worker adds a real protected `GET /v1/me` endpoint. The Worker continues to rely on Access-provided identity for authenticated requests. It does not perform D1 allowlist checks yet.

## End-To-End Flow

### First run

1. User runs `rescript binding publish`.
2. The CLI checks the cached token bundle for the publish hostname.
3. If no usable token exists, the CLI starts a temporary HTTP listener on an ephemeral `127.0.0.1` port.
4. The CLI generates `state`, PKCE verifier, and PKCE challenge.
5. The CLI discovers the authorization server using:

```text
https://<publish-hostname>/.well-known/oauth-authorization-server
```

6. The CLI opens the browser to the Cloudflare Access authorization endpoint.
7. The user logs in with GitHub through Access.
8. Access redirects back to the local loopback callback.
9. The CLI validates `state`, exchanges the code for tokens, persists the token bundle, and shuts down the temporary listener.
10. The CLI calls `GET /v1/me`.
11. On success, the CLI prints a short confirmation and exits.

### Later runs

1. `publish` loads the cached token bundle.
2. If the access token is still valid, it calls `GET /v1/me`.
3. If the access token is expired and a refresh token exists, it refreshes first, updates the cache, and then calls `GET /v1/me`.
4. If refresh fails or the cache is invalid, the CLI falls back to the browser login flow.

## Token Cache

Store auth in a user-level directory keyed by publish hostname, not in the repository.

Recommended path shape:

- Linux: `~/.local/state/rescript-bindings/oauth/<hostname>.json`
- macOS: `~/Library/Application Support/rescript-bindings/oauth/<hostname>.json`
- Windows: `%AppData%/rescript-bindings/oauth/<hostname>.json`

Recommended cache payload:

- `accessToken`
- `refreshToken`
- `expiresAt`
- `tokenEndpoint`
- `authorizationEndpoint`
- `clientId`
- `scopes` when returned
- `resource`
- `publishBaseUrl`

Cache behavior:

- the cache is disposable
- invalid JSON, hostname mismatch, or refresh failure causes the CLI to ignore or replace the cache
- v1 uses a plain file with restrictive permissions where the OS supports it
- v1 does not integrate with the OS keychain

## CLI Behavior

For this slice, `publish` enters auth-check mode before any future publish prompts or file scanning.

Behavior:

1. load cached auth
2. reuse valid access token when possible
3. refresh when needed
4. perform browser login when refresh is unavailable or fails
5. call `GET /v1/me`
6. print success and exit

Recommended success output when `githubLogin` is available:

```text
Authenticated as <github-login>
```

If `githubLogin` is missing but auth succeeded, the CLI should fall back to another available identifier such as email or display name rather than treating the login as failed.

Errors must be explicit and exit non-zero. Failures should not silently retry forever.

Examples of targeted failures:

- unable to start local callback server
- browser launch failed
- OAuth callback timed out
- state validation failed
- token exchange failed
- token refresh failed
- authenticated request to `/v1/me` failed

## `/v1/me` Contract

`GET /v1/me` is protected by Cloudflare Access and returns the minimum identity shape needed for the CLI to confirm a successful login.

Recommended response:

```json
{
  "githubLogin": "josh",
  "displayName": "Josh",
  "email": "user@example.com",
  "access": {
    "authenticated": true
  }
}
```

Contract rules:

- the route succeeds only for authenticated Access requests
- GitHub-specific fields may be nullable if Access does not provide them in a given request
- lack of GitHub-specific fields should not fail this slice
- D1 allowlist enforcement is intentionally out of scope here

## Files And Responsibilities

Expected implementation shape:

- `src/Cli.res`
  - orchestrates the `publish` command auth-check flow
- `src/Main.res`
  - invokes the updated publish flow
- `src/Worker.res`
  - implements protected `GET /v1/me`
- `src/bindings/...`
  - only add bindings if needed for ReScript orchestration
- `src/js/...` or equivalent helper path
  - JavaScript OAuth helper for PKCE, browser launch, callback listener, token exchange, refresh, and cache file IO
- `test/...`
  - unit tests for cache logic, auth branching, and `/v1/me`

The helper should stay narrow. It is not a general registry client and should not absorb future publish prompting or upload logic.

## Error Handling

The main failure classes in this slice are:

- local environment failures
  - cannot bind callback port
  - cannot open browser
- OAuth protocol failures
  - missing callback parameters
  - invalid state
  - code exchange rejection
  - refresh rejection
- server-side failures
  - unauthenticated `/v1/me`
  - malformed identity response

Handling rules:

- fail fast with targeted messages
- delete or ignore corrupted cache files
- do not continue into publish prompts if auth is not confirmed
- do not introduce fallback auth modes in this slice

## Testing

### Automated

Add unit tests for:

- PKCE/state generation shape
- cache load/save behavior
- token expiry decisions
- refresh-vs-browser-login branching
- `publish` invoking auth before any later publish work
- `/v1/me` response shaping

### Manual verification

Use one real Cloudflare verification checklist:

1. run `rescript binding publish`
2. browser opens
3. GitHub login completes
4. local token cache file appears
5. CLI prints authenticated identity
6. run `rescript binding publish` again
7. second run succeeds without reopening the browser while the cached token is still usable

## Out Of Scope

The following are explicitly deferred:

- D1-backed publisher allowlist checks
- full publish metadata prompts
- folder walking and file validation during publish
- release upload to `POST /v1/releases`
- admin publisher management flows
- OS keychain integration
- headless auth flows
- additional identity providers

## Next Step

After this spec is approved, write an implementation plan that decomposes the work into small tasks covering:

- Cloudflare config assumptions
- CLI auth orchestration
- OAuth helper implementation
- `/v1/me` Worker implementation
- unit tests
- manual verification steps
