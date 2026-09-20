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

`publish` authenticates through Cloudflare Access OAuth for CLIs, verifies that the identity is an approved publisher, prompts for package metadata and source files, and sends releases to the protected publish API.

This repository is a pnpm monorepo. The current package is implemented in **ReScript v12** with a Node CLI bundle and a Cloudflare Worker registry API.

## Layout

- `packages/api`: Cloudflare Worker registry API, D1 schema, validation, and API tests.
- `packages/cli`: bundled Node CLI for discovery, installation, updates, publishing, and release deletion.
- `packages/web`: Xote SSR frontend Worker for browsing the registry.
- `packages/skills`: shared Codex/Claude skills for creating ReScript bindings.
- `packages/cli/src/Command.res`: Commander-powered CLI entrypoint.
- `packages/api/src/Worker.res`: registry routing, publisher authorization, D1 persistence, and publish validation.
- `packages/cli/src/bindings/RegistryAdd.res`: Node/TTY/filesystem orchestration for installing bindings.
- `packages/cli/src/bindings/PublishOAuth.res`: Node/browser/OAuth orchestration for publishing bindings.
- `packages/cli/src/add/*.res`: ReScript-owned add-flow rules for package names, install paths, and release table rows.
- `packages/cli/src/publish/*.res`: ReScript-owned publish-flow rules for token strategy and binding source discovery.
- `packages/cli/src/core/PackageJson.res`: shared dependency lookup rules for parsed `package.json` contents.
- `packages/api/src/core/RegistryConfig.res`: shared registry endpoints.
- `packages/api/src/core/Validation.res`: upload/path/size validation rules and slug helpers.
- `packages/api/src/core/RegistryTypes.res`: shared domain types for releases, files, and publish payloads.
- `packages/cli/src/bindings/*`: ReScript externals for runtime boundaries.
- `packages/api/schema.sql`: D1 schema for publishers, releases, files, and audit log.

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
node ./packages/cli/bin/index.mjs list
node ./packages/cli/bin/index.mjs search react
node ./packages/cli/bin/index.mjs update
node ./packages/cli/bin/index.mjs publish
node ./packages/cli/bin/index.mjs delete
```

## Agent Skills

`packages/skills` contains `rescript-bindings-generator`, a shared skill for
creating ReScript bindings for a named npm package.

Install it into Codex from a local checkout:

```bash
mkdir -p ~/.codex/skills
ln -s "$(pwd)/packages/skills/rescript-bindings-generator" ~/.codex/skills/rescript-bindings-generator
```

Restart Codex after installing. Then ask for the skill by name:

```text
Use $rescript-bindings-generator to create ReScript bindings for jotai.
```

For Claude Code plugin-based local development, load the package as a plugin:

```bash
cc --plugin-dir "$(pwd)/packages/skills"
```

The Claude plugin manifest is in `packages/skills/.claude-plugin/plugin.json`,
and its `skills/rescript-bindings-generator` entry points at the same canonical
skill used by Codex.

## Worker

Run Wrangler against the API package workspace:

```bash
pnpm --filter @jvlk/rescript-bindings-api run dev
pnpm --filter @jvlk/rescript-bindings-api run deploy
```

The API Worker requires `PUBLISHER_ADMIN_IDENTITIES`, a comma-separated list of Cloudflare Access email or GitHub-login claims allowed to manage publisher approvals. The deployed Worker config currently bootstraps `josh@vlkpack.com`.

An administrator can approve or deactivate a publisher with an authenticated request:

```http
POST /api/publish/v1/admin/publishers
Content-Type: application/json

{
  "githubLogin": "publisher-login",
  "email": "publisher@example.com",
  "active": true
}
```

`email` is currently required because Cloudflare Access supplies the verified email claim used for authorization. `githubLogin` is normalized to lowercase for its case-insensitive D1 key and remains available for GitHub-backed identity claims.

`GET /api/publish/v1/me` reports `access.authenticated`, `access.publisherApproved`, and `access.admin`. Only active publishers and configured administrators may create releases.

## API Base

The CLI uses the Worker API route:

```text
https://rescript-binding-registry.josh-401.workers.dev/api/publish
```

Public registry reads are routed under `/api/v1/...`; protected publish/admin endpoints are routed under `/api/publish/v1/...`. Separate publish/read subdomains are not used.
