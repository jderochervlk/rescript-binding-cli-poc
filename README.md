# ReScript Binding Registry POC

This repository is implemented in **ReScript v12** with a Node CLI bundle and a Cloudflare Worker registry API.

## Layout

- `src/Command.res`: Commander-powered CLI entrypoint for `add` and `publish`.
- `src/Worker.res`: Cloudflare Worker runtime entrypoint, registry routing, and publish validation.
- `src/bindings/RegistryAdd.res`: Node/TTY/filesystem orchestration for installing bindings.
- `src/bindings/PublishOAuth.res`: Node/browser/OAuth orchestration for publishing bindings.
- `src/add/*.res`: ReScript-owned add-flow rules for package names, install paths, and release table rows.
- `src/publish/*.res`: ReScript-owned publish-flow rules for token strategy and binding source discovery.
- `src/core/PackageJson.res`: shared dependency lookup rules for parsed `package.json` contents.
- `src/core/RegistryConfig.res`: shared hard-coded registry endpoints for the PoC.
- `src/core/Validation.res`: upload/path/size validation rules and slug helpers.
- `src/core/RegistryTypes.res`: shared domain types for releases, files, and publish payloads.
- `src/bindings/*`: ReScript externals for runtime boundaries.
- `schema.sql`: D1 schema for publishers, releases, files, and audit log.
- `rescript.json`: ReScript project configuration (replaces the legacy `bsconfig.json` format).

## Commands

```bash
npm install
npm run build
npm test
```

`npm run build` type-checks ReScript and regenerates `bin/index.mjs`. `npm test` runs the build and the current script-based test suite.

## CLI

Install published bindings:

```bash
node ./bin/index.mjs add
node ./bin/index.mjs add @inquirer/prompts
node ./bin/index.mjs add @inquirer/prompts --folder vendor/bindings
```

When the package argument is omitted, `add` offers an interactive selector populated from `peerDependencies`, `dependencies`, and `devDependencies` in the local `package.json`. The release picker shows author, JavaScript package compatibility, and ReScript compatibility in a table.

For single-file releases, `add` prompts for the install file path and defaults to a ReScript-safe PascalCase filename derived from the package name, for example:

```text
src/bindings/InquirerPrompts.res
```

The user may choose another directory, but the final file basename is normalized to a valid ReScript module filename. For example, `custom/path/inquirerPrompts.res` writes `custom/path/InquirerPrompts.res`.

Publish bindings:

```bash
node ./bin/index.mjs publish
```

`publish` authenticates through Cloudflare Access OAuth for CLIs, prompts for package metadata and source files, and sends releases to the protected publish API.

## API Base

The CLI uses the Worker API route:

```text
https://rescript-binding-registry.josh-401.workers.dev/api/publish
```

Public registry reads are routed under `/api/v1/...`; protected publish/admin endpoints are routed under `/api/publish/v1/...`. Separate publish/read subdomains are not used.
