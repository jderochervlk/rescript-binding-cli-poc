# ReScript Binding Registry Design

**Date:** 2026-04-18
**Status:** In progress
**Owner:** ReScript team

## Summary

Build a Cloudflare-hosted registry and CLI workflow for publishing and installing ReScript bindings. End users run `rescript-bindings add [package]` to browse available releases for a JavaScript library, inspect author and compatibility metadata, and copy the selected binding into their local project. Approved contributors run `rescript-bindings publish` to upload local `.res` and `.resi` files through a Cloudflare Access OAuth flow for CLIs.

This design keeps read access fully public, limits publish access to an allowlisted set of GitHub accounts, and stores binding metadata and file contents in Cloudflare D1 for operational simplicity in v1.

## Goals

- Let users discover and install published bindings from the ReScript CLI.
- Let approved contributors publish bindings directly from a local folder.
- Show compatibility metadata before install:
  - publisher
  - target package version range
  - supported ReScript version range
- Prompt for a ReScript-safe install filename, with a CLI override via `--folder`.
- Ask for confirmation before overwriting existing files.
- Use Cloudflare-managed infrastructure for hosting, auth, and persistence.
- Avoid authentication for public read/install flows.

## Non-Goals

- General project scaffolding or template distribution.
- Publishing arbitrary file types.
- A moderation or approval queue before release.
- In-place editing of published releases.
- Automatic update, remove, or sync commands in v1.
- A custom OAuth provider or first-party identity service.

## Product Surface

### Consumer workflow

Users install a binding with:

```bash
rescript-bindings add jotai
```

If the package argument is omitted, the CLI offers an interactive package selector populated from the local `package.json`.

The CLI:

1. Reads the local project to detect:
   - the installed package version for `jotai`
   - the local `rescript` version
2. Fetches all active published releases for `jotai`.
3. Ranks compatible variants first, while still showing all variants.
4. Renders an interactive release table showing:
   - author
   - package range and whether it matches the installed package
   - ReScript range and whether it matches the local project
5. Prompts for the install file path for single-file releases.
6. Defaults single-file installs to a ReScript-safe PascalCase filename under `src/bindings`, for example `src/bindings/Jotai.res`.
7. Allows another directory/path, but validates and normalizes the final filename as a valid ReScript module filename.
8. If `--folder <path>` is provided, installs into that folder and still normalizes release filenames.
9. If any target file already exists, asks for confirmation before overwriting.

### Contributor workflow

Approved contributors publish with:

```bash
rescript-bindings publish
```

The CLI:

1. Uses Cloudflare Access OAuth for CLIs to authenticate against the publish API.
2. Prompts every time for:
   - package name, with an interactive selector from local dependencies when available
   - local file or folder path, with filesystem completion
   - package version range, defaulting to the selected installed package version
   - ReScript version range, defaulting from the local project
3. Walks the selected source recursively when it is a folder.
4. Rejects any file that is not `.res` or `.resi`.
5. Uploads the prompted metadata plus file contents to the publish API.
6. Prints the resulting release id and package metadata.

No checked-in publish manifest is required in v1. The CLI constructs the manifest in memory on every publish.

## Architecture

### Runtime

Use a single Cloudflare Worker codebase exposed at:

- `https://rescript-binding-registry.josh-401.workers.dev`

The API lives under the `/api` route group:

- `/api/v1/packages/...` and `/api/v1/releases/...`
  - public read endpoints for listing and fetching binding releases
- `/api/publish/v1/me`, `/api/publish/v1/releases`, and `/api/publish/v1/admin/...`
  - protected publish and admin endpoints behind Cloudflare Access

The Worker is responsible for:

- validating incoming payloads
- ranking compatibility for discovery responses
- verifying Access identity on protected routes
- checking the publisher allowlist
- reading and writing D1 records

### Authentication and authorization

Protected routes are fronted by Cloudflare Access configured with GitHub as the identity provider. This avoids implementing GitHub OAuth flows, token storage, and session management inside the registry service.

Publish/auth flow:

1. Contributor runs `rescript-bindings publish`.
2. The CLI starts the Cloudflare Access OAuth flow for CLI clients and opens the user's browser.
3. The CLI caches the resulting token bundle locally for the registry host.
4. The CLI sends the publish request with the Access bearer token expected by the protected endpoint.
5. The Worker validates the Access assertion.
6. The Worker resolves the authenticated identity and checks it against an internal allowlist in D1.
7. If the account is allowlisted, the publish proceeds immediately.

Public read endpoints do not require authentication.

### Storage

Use Cloudflare D1 for all v1 persistence:

- contributor allowlist
- binding release metadata
- uploaded file contents
- publish audit history

This is acceptable for v1 because:

- binding uploads are small
- only `.res` and `.resi` files are allowed
- install is copy-based, not package-manager-based
- operational simplicity matters more than maximum storage scale

If binding size or volume later exceeds D1’s comfortable range, file contents can move to R2 without changing the public install contract.

## Binding Model

A published binding is an immutable release containing:

- a package namespace, such as `jotai`
- a human-readable variant label
- compatibility metadata
- a folder-shaped set of source files
- publisher metadata
- creation timestamp

Each publish creates a new immutable release id. Existing releases are never edited in place.

Releases may later be marked deprecated, but v1 does not support mutation or moderation states.

## Data Model

### `approved_publishers`

- `github_login` text primary key
- `email` text nullable
- `active` integer not null
- `added_at` text not null
- `added_by` text not null

This table defines who is permitted to publish.

### `binding_releases`

- `id` text primary key
- `package_name` text not null
- `variant_label` text not null
- `variant_slug` text not null
- `publisher_login` text not null
- `publisher_display_name` text not null
- `peer_package_range` text not null
- `rescript_range` text not null
- `description` text nullable
- `file_count` integer not null
- `manifest_sha256` text not null
- `status` text not null
- `created_at` text not null

Recommended uniqueness constraint:

- unique on `(package_name, variant_slug, peer_package_range, rescript_range, manifest_sha256)`

This allows clearly distinct releases while preventing identical duplicate uploads.

### `binding_files`

- `release_id` text not null
- `relative_path` text not null
- `content` text not null
- `sha256` text not null
- `bytes` integer not null

Recommended uniqueness constraint:

- unique on `(release_id, relative_path)`

### `publish_audit_log`

- `id` text primary key
- `release_id` text not null
- `publisher_login` text not null
- `action` text not null
- `created_at` text not null
- `metadata_json` text nullable

This is append-only and records successful publish activity.

## API Design

### Public API

#### `GET /api/v1/packages/:package/releases`

Returns all active releases for a package.

Query parameters:

- `packageVersion` optional
- `rescriptVersion` optional

Behavior:

- returns all active releases for the package
- includes compatibility booleans and a ranking score
- sorts compatible releases first when versions are supplied

Example response fields:

- `id`
- `packageName`
- `variantLabel`
- `variantSlug`
- `publisherLogin`
- `peerPackageRange`
- `rescriptRange`
- `description`
- `createdAt`
- `isPackageCompatible`
- `isRescriptCompatible`
- `compatibilityRank`

#### `GET /api/v1/releases/:id`

Returns:

- release metadata
- file list
- file contents

This is the install payload consumed by `rescript-bindings add`.

### Protected API

#### `GET /api/publish/v1/me`

Returns:

- authenticated contributor identity
- whether the identity is allowlisted

This can be used by the CLI to fail early before prompting for publish input.

#### `POST /api/publish/v1/releases`

Creates a new release from an interactive CLI publish flow.

Request payload:

- package name
- variant label
- package range
- ReScript range
- optional description
- file entries with relative path and content

Validation:

- authenticated identity must be allowlisted
- all files must be `.res` or `.resi`
- all paths must be normalized relative paths
- no duplicate paths after normalization
- no empty file set
- semver ranges must parse
- content and row sizes must stay below configured limits

On success:

- inserts the immutable release
- inserts file rows
- writes an audit log row
- returns the published release metadata

#### `POST /api/publish/v1/admin/publishers`

Administrative endpoint for adding or deactivating approved publishers. This is not required for the consumer-facing MVP, but the API boundary should exist from the beginning.

## CLI Design

### `rescript-bindings add [package]`

Inputs:

- optional package name argument
- optional `--folder <path>`

Default destination:

- single-file releases default to `src/bindings/<PascalPackageName>.<res|resi>`
- multi-file releases default to `src/bindings/<PascalPackageName>/...`

Install behavior:

1. Read local package metadata from the current project.
2. If the package argument is omitted, prompt from local dependencies.
3. Detect the installed version of the requested package.
4. Detect the local ReScript version.
5. Request available releases from the registry.
6. Show an interactive release table sorted by compatibility.
7. Fetch the selected release payload.
8. For single-file releases, prompt for an install file path and normalize the basename to a valid ReScript module filename.
9. For folder installs, materialize files under the selected destination root while normalizing final ReScript filenames.
10. If any file exists already, prompt before overwriting.

The CLI should not silently skip files or attempt merge semantics. The user either confirms overwrite or cancels the install.

### `rescript-bindings publish`

Inputs:

- no required flags in v1

Publish behavior:

1. Authenticate or refresh through Cloudflare Access OAuth for CLIs.
2. Verify contributor auth by calling `GET /api/publish/v1/me`.
3. Prompt for all release metadata.
4. Prompt for the local file or folder path.
5. Walk the selected source recursively when it is a folder.
6. Filter and validate `.res` and `.resi` files only.
7. Show a publish preview:
   - package
   - version ranges
   - file count
   - file paths
8. Submit the release payload.
9. Print the resulting release id and confirmation.

No local manifest file is created in v1.

## Validation Rules

The registry accepts only source binding uploads.

Accepted:

- `.res`
- `.resi`

Rejected:

- hidden files
- hidden directories
- any file with an extension other than `.res` or `.resi`
- binary content
- empty uploads
- duplicate paths after normalization
- paths containing traversal segments that escape the uploaded folder root
- install target basenames that cannot normalize to ReScript module filenames

Operational limits:

- maximum 200 files per release
- maximum 200 KB per file
- maximum 2 MB total source content per release

The publish API enforces these limits before any D1 writes occur.

## Error Handling

### Consumer errors

- package not found: return an empty list and print a clear CLI message
- no compatible releases: still show all releases, but mark them incompatible
- destination collisions: ask for overwrite confirmation
- network failure: fail without partial file writes

### Contributor errors

- not authenticated: start or retry the Cloudflare Access OAuth flow
- not allowlisted: fail before prompting for upload details
- invalid range: fail validation and keep the prompt flow local until corrected
- invalid files: report the exact offending paths
- oversized upload: fail with a clear size-based error message

## Security Model

- Public read endpoints are anonymous.
- Publish endpoints require Cloudflare Access plus a D1 allowlist check.
- The Worker validates the Access assertion on every protected request.
- The allowlist is the final authorization gate.
- Release contents are immutable after publish.
- Every publish is auditable.

This keeps the security boundary narrow:

- Access proves user identity
- the registry decides who may publish
- anonymous consumers never need credentials

## Rollout Plan

### Phase 1: Registry MVP

- Worker routing for public and protected APIs
- D1 schema for publishers, releases, files, and audit log
- public list and fetch endpoints
- protected publish endpoint
- strict upload validation for `.res` and `.resi`

### Phase 2: CLI MVP

- `rescript-bindings add [package]`
- `rescript-bindings publish`
- compatibility-aware release picker
- package selector from local dependencies
- install file/path prompt with ReScript filename normalization
- `--folder` override
- overwrite confirmation

### Phase 3: Hardening

- release deprecation
- richer search and ranking
- contributor/admin tooling for publisher management
- optional install manifest for later update/remove commands
- optional R2 migration if D1 file storage becomes limiting
- optional richer browser/auth UX once the PoC flow is stable

## Design Decisions

- Use top-level `add` and `publish` commands in the PoC CLI instead of requiring an extra `binding` namespace.
- Use interactive publishing instead of a checked-in manifest file.
- Allow folder uploads, not just single-file uploads.
- Allow only `.res` and `.resi` source files.
- Store source file contents in D1 for v1.
- Require overwrite confirmation on install.
- Publish immediately after successful validation for allowlisted contributors.
- Use Cloudflare Access with GitHub as the identity provider for publishing, and use the CLI OAuth flow rather than `cloudflared`.

## Current Implementation Checkpoint

- CLI commands are top-level `add` and `publish`, backed by the bundled `bin/index.mjs`.
- Public read endpoints use `/api/v1/...`; protected publish endpoints use `/api/publish/v1/...`.
- Add-flow domain rules now live in small documented ReScript modules under `src/add`.
- Publish-flow domain rules now live in small documented ReScript modules under `src/publish`.
- Parsed package dependency lookup now lives in `src/core/PackageJson.res` and is shared by add and publish.
- Registry endpoint constants live in `src/core/RegistryConfig.res`.
- JS files remain for Node runtime interop: Commander, TTY prompts, browser launch, OAuth loopback server, filesystem reads/writes, and HTTP calls.
- Focused ReScript tests cover the extracted add and publish rules, and the existing JS integration tests cover the orchestration boundary.

## Rationale

This design optimizes for the smallest system that is still operationally credible:

- simple contributor auth through Cloudflare Access
- no auth burden on consumers
- deterministic immutable releases
- strict file-type limits
- no object-storage dependency until scale requires it
- CLI flows that match how ReScript users already work locally

It keeps the future migration paths open without overbuilding v1.
