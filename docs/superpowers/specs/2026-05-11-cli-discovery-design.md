# CLI Discovery Commands Design

**Date:** 2026-05-11
**Status:** Approved design
**Owner:** ReScript team

## Summary

Add first-class discovery commands to the binding registry CLI:

```bash
rescript-bindings list
rescript-bindings search <query>
rescript-bindings recent
rescript-bindings get
```

These commands expose the same registry discovery surface as the web site. `list`,
`search`, and `recent` are read-only browsing commands. `get` scans the local
`package.json`, finds bindings for installed dependencies, prompts the user to
choose a release for each matching dependency, then asks for one final approval
before installing the selected releases.

## Goals

- Let users browse available bindings from the CLI without opening the web site.
- Keep discovery commands top-level, matching the existing `add` and `publish`
  command style.
- Make `list` show a capped all-bindings view, defaulting to 50 entries for now.
- Support package-name search from the CLI.
- Keep `recent` as a quick view of recently updated bindings.
- Let `get` detect local dependency matches and install selected bindings after
  explicit approval.
- Reuse the existing add/install behavior for fetching releases, writing files,
  ReScript module filename normalization, and overwrite confirmation.

## Non-Goals

- Add update, remove, or sync commands.
- Add non-interactive bulk install in v1.
- Install every matching release automatically.
- Add advanced fuzzy scoring in the CLI if the registry API already provides the
  search ranking.
- Change publish behavior.

## Command Behavior

### `rescript-bindings list`

`list` prints grouped binding entries from a capped all-bindings registry API
view. The default limit is 50.

The output should use a compact table shape:

- package name
- author display name
- supported library version ranges
- supported ReScript version ranges
- latest publish timestamp

The command should support `--limit <n>` as a small extension point, with 50 as
the default. If the implementation needs to clamp the maximum later, the CLI can
do that without changing the command contract.

### `rescript-bindings search <query>`

`search` calls the registry search endpoint and prints the same grouped table
shape as `list`. Empty queries should fail locally with a clear usage error
rather than calling the registry.

The initial search behavior can rely on the existing API package-name matching.
The CLI does not need to add a second ranking algorithm.

### `rescript-bindings recent`

`recent` calls the existing recent-bindings endpoint and prints the same grouped
table shape. It is intended as the CLI equivalent of the web site's default
recently updated page.

### `rescript-bindings get`

`get` reads the local `package.json`, gathers dependency names from
`peerDependencies`, `dependencies`, and `devDependencies`, and excludes
`rescript`.

For each dependency:

1. Look up matching binding entries by exact package name.
2. Skip dependencies with no matching binding entries.
3. If one or more entries/releases match, prompt the user to choose the release
   to install for that dependency.
4. Include package, author, library range, ReScript range, variant, and publish
   date in the prompt choice labels.

After all dependency choices are collected, `get` shows a single install plan and
asks for final approval before any files are written. If approved, it installs
each selected release by reusing the existing release fetch and file write path
from `add`.

If no dependencies have matching bindings, `get` prints a clear message and exits
without prompting for approval.

## API Design

The CLI should reuse existing public read endpoints where possible:

- `GET /api/v1/bindings/search?q=<query>`
- `GET /api/v1/bindings/recent`
- `GET /api/v1/bindings/:package/authors/:author`
- `GET /api/v1/packages/:package/releases`
- `GET /api/v1/releases/:id`

Add one capped all-bindings endpoint:

```text
GET /api/v1/bindings?limit=50
```

The response should match the current grouped discovery response shape used by
the web site:

```json
{
  "entries": [
    {
      "packageName": "react",
      "author": "josh",
      "authorDisplayName": "Josh",
      "libraryVersions": ["^19.0.0"],
      "rescriptVersions": ["^12.0.0"],
      "latestCreatedAt": "2026-05-10T13:00:00.000Z",
      "releases": []
    }
  ]
}
```

For `get`, exact package matching should use
`GET /api/v1/packages/:package/releases` with the detected package and ReScript
versions. That endpoint already returns the release choices needed for the
per-dependency prompt and avoids fuzzy search false positives.

## CLI Architecture

Add a small discovery module under the CLI package that owns:

- fetching grouped binding entries
- formatting entry rows
- selecting releases for `get`
- printing no-result and error messages

Keep install behavior in the existing add/install module. If necessary, extract a
shared install helper from the current `add` path so both `add` and `get` can
install a known release id without duplicating file planning, filename
normalization, collision checks, or writes.

The top-level Commander entrypoint should add `list`, `search`, `recent`, and
`get` next to the existing `add` and `publish` commands.

## Error Handling

- Registry network failures should fail the command without partial file writes.
- Invalid or missing local `package.json` should be handled the same way as the
  current `add` dependency selector path.
- `get` should require an interactive terminal when release selection or final
  approval is needed.
- Empty `search` query should be rejected locally.
- If a selected install collides with existing files, keep the existing overwrite
  confirmation behavior.
- If the final `get` approval is denied, no selected release should be installed.

## Testing

Add focused ReScript tests for:

- URL construction and response parsing for `list`, `search`, and `recent`.
- Table row formatting for grouped binding entries.
- `get` dependency scanning and exact package match filtering.
- `get` per-dependency release selection.
- `get` final approval preventing file writes.
- `get` approved install reusing the same write path as `add`.
- Commander help/parse coverage for the four new top-level commands.
- Worker API coverage for `GET /api/v1/bindings?limit=50`.

Full package verification should run through the existing package test command:

```bash
pnpm --filter @jvlk/rescript-bindings test
```
