# ReScript Bindings CLI

This package contains the ReScript-powered CLI for discovering, installing, updating, publishing, and deleting source bindings from the ReScript binding registry.

## Commands

From the repository root:

```bash
pnpm --filter @jvlk/rescript-bindings build
pnpm --filter @jvlk/rescript-bindings test
```

From this package directory:

```bash
pnpm build
pnpm test
```

## CLI

```bash
pnpx @jvlk/rescript-bindings list
pnpx @jvlk/rescript-bindings search react
pnpx @jvlk/rescript-bindings get react publisher-login
pnpx @jvlk/rescript-bindings add react
pnpx @jvlk/rescript-bindings update
pnpx @jvlk/rescript-bindings publish
pnpx @jvlk/rescript-bindings delete
```

`add` and the discovery commands use the public registry API without authentication. `publish` and `delete` authenticate through Cloudflare Access Managed OAuth. Publishing is available only to identities approved by a registry administrator; the CLI checks that approval through `/api/publish/v1/me` before starting the publish prompts.

For local development after building:

```bash
node ./bin/index.mjs add
node ./bin/index.mjs publish
```
