# ReScript Bindings CLI

This package contains the ReScript-powered CLI for discovering, installing, updating, publishing, and deleting source bindings from the ReScript binding registry.

## Requirements

- Node.js 22.13 or newer
- Network access to the binding registry for registry commands

The published CLI is a self-contained Node.js bundle and does not install the registry API workspace package or its other build-time dependencies.

## Commands

From the repository root:

```bash
pnpm --filter @jvlk/rescript-bindings build
pnpm --filter @jvlk/rescript-bindings test
pnpm --filter @jvlk/rescript-bindings test:package
```

From this package directory:

```bash
pnpm build
pnpm test
pnpm test:package
```

`test:package` builds and packs the npm package, installs it into a clean temporary project in offline mode, and runs the installed executable. Run it before publishing to catch missing bundle files or accidental runtime workspace dependencies.

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
