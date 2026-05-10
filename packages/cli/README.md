# ReScript Bindings CLI

This package contains the ReScript-powered CLI and Cloudflare Worker registry API for the binding registry PoC.

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
node ./bin/index.mjs add
node ./bin/index.mjs publish
```
