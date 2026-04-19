# ReScript Binding Registry POC

This repository is implemented in **ReScript v12**, with runtime bindings kept under `src/bindings`.

## Layout

- `src/Worker.res`: registry API surface + request handling for public/protected routes.
- `src/Cli.res`: `rescript binding add` and `rescript binding publish` command flow.
- `src/core/Validation.res`: upload/path/size validation rules and slug helpers.
- `src/core/RegistryTypes.res`: shared domain types for releases, files, and publish payloads.
- `src/bindings/*`: runtime externals (Node process/path/fs and fetch).
- `schema.sql`: D1 schema for publishers, releases, files, and audit log.
- `rescript.json`: ReScript project configuration (replaces the legacy `bsconfig.json` format).

## Commands

```bash
npm install
npm run build
npm test
```

`npm test` currently aliases the ReScript build so type-checking and codegen are always enforced.
