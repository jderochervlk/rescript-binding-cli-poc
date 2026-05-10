# ReScript Binding Registry POC

## Use The CLI

Install published bindings into a ReScript project:

```bash
pnpx @jvlk/rescript-bindings add jotai
```

Publish local bindings:

```bash
pnpx @jvlk/rescript-bindings publish
```

When the package argument is omitted, `add` offers an interactive selector populated from `peerDependencies`, `dependencies`, and `devDependencies` in the local `package.json`. The release picker shows author, JavaScript package compatibility, and ReScript compatibility in a table.

For single-file releases, `add` prompts for the install file path and defaults to a ReScript-safe PascalCase filename derived from the package name, for example:

```text
src/bindings/InquirerPrompts.res
```

The user may choose another directory, but the final file basename is normalized to a valid ReScript module filename. For example, `custom/path/inquirerPrompts.res` writes `custom/path/InquirerPrompts.res`.

`publish` authenticates through Cloudflare Access OAuth for CLIs, prompts for package metadata and source files, and sends releases to the protected publish API.

This repository is a pnpm monorepo. The current package is implemented in **ReScript v12** with a Node CLI bundle and a Cloudflare Worker registry API.

## Layout

- `packages/cli`: CLI package and Worker registry API.
- `packages/cli/src/Command.res`: Commander-powered CLI entrypoint for `add` and `publish`.
- `packages/cli/src/Worker.res`: Cloudflare Worker runtime entrypoint, registry routing, and publish validation.
- `packages/cli/src/bindings/RegistryAdd.res`: Node/TTY/filesystem orchestration for installing bindings.
- `packages/cli/src/bindings/PublishOAuth.res`: Node/browser/OAuth orchestration for publishing bindings.
- `packages/cli/src/add/*.res`: ReScript-owned add-flow rules for package names, install paths, and release table rows.
- `packages/cli/src/publish/*.res`: ReScript-owned publish-flow rules for token strategy and binding source discovery.
- `packages/cli/src/core/PackageJson.res`: shared dependency lookup rules for parsed `package.json` contents.
- `packages/cli/src/core/RegistryConfig.res`: shared hard-coded registry endpoints for the PoC.
- `packages/cli/src/core/Validation.res`: upload/path/size validation rules and slug helpers.
- `packages/cli/src/core/RegistryTypes.res`: shared domain types for releases, files, and publish payloads.
- `packages/cli/src/bindings/*`: ReScript externals for runtime boundaries.
- `packages/cli/schema.sql`: D1 schema for publishers, releases, files, and audit log.
- `packages/cli/rescript.json`: ReScript project configuration (replaces the legacy `bsconfig.json` format).

## Commands

```bash
corepack enable
pnpm install
pnpm build
pnpm test
```

`pnpm build` type-checks ReScript and regenerates `packages/cli/bin/index.mjs`. `pnpm test` runs the build and the current script-based test suite.

## Local CLI

```bash
node ./packages/cli/bin/index.mjs add jotai
node ./packages/cli/bin/index.mjs publish
```

## Worker

Run Wrangler against the CLI package workspace:

```bash
pnpm --filter @jvlk/rescript-bindings exec wrangler dev --local
pnpm --filter @jvlk/rescript-bindings exec wrangler deploy
```

## API Base

The CLI uses the Worker API route:

```text
https://rescript-binding-registry.josh-401.workers.dev/api/publish
```

Public registry reads are routed under `/api/v1/...`; protected publish/admin endpoints are routed under `/api/publish/v1/...`. Separate publish/read subdomains are not used.
