# Binding Registry Frontend Design

Date: 2026-05-10
Status: Draft for review

## Summary

Build a separate frontend Worker for browsing the ReScript binding registry. The existing registry Worker remains the source of truth for release data and gains public discovery endpoints for recent bindings, fuzzy package search, and package-author detail data. The frontend Worker renders simple Xote pages, uses Pico CSS from the CDN, and does not read D1 directly.

The first implementation path is server-rendered Xote on Cloudflare Workers. If Xote SSR proves impractical in the Worker runtime or build pipeline, the fallback is a client-rendered Xote app that consumes the same public API contracts.

## Goals

- Add a homepage with a search bar and a recently updated bindings table.
- Let users search binding entries by fuzzy package-name matching.
- Group list rows by package name and author.
- Show package name, author, library versions, and ReScript versions in list tables.
- Add a detail page for one package-author group.
- Show published binding source in a plain `pre` and `code` block.
- Keep styling simple with Pico CSS from the CDN.
- Keep the frontend Worker separate from the registry API Worker.

## Non-Goals

- No syntax highlighting in this slice.
- No authenticated publisher UI.
- No D1 binding in the frontend Worker.
- No CDN-free CSS asset pipeline in this slice.
- No advanced fuzzy index or external search service.

## Architecture

The repository stays a pnpm monorepo with a new `packages/web` workspace package. The existing `packages/cli` package continues to own the CLI and registry API Worker.

`packages/web` owns:

- its own `package.json`
- its own `rescript.json`
- its own `wrangler.toml`
- Xote page components and Worker routing

The web Worker fetches data from the public registry API. It does not bind to the registry D1 database, and it does not duplicate SQL. The registry API exposes frontend-shaped public endpoints so the web package can stay mostly presentation-oriented.

## Registry API Additions

### `GET /api/v1/bindings/recent`

Returns recently updated binding entries grouped by `package_name` and `publisher_login`.

Each entry contains:

- `packageName`
- `author`
- `authorDisplayName`
- `libraryVersions`
- `rescriptVersions`
- `latestCreatedAt`
- `releases`

`libraryVersions` is the distinct set of `peer_package_range` values this author has published for the package. `rescriptVersions` is the distinct set of `rescript_range` values this author has published for the package.

Results are ordered by the most recent published release in each package-author group.

### `GET /api/v1/bindings/search?q=<query>`

Returns the same grouped entry shape as `recent`.

Search matches package names with substring matching for v1, using D1 `LIKE` over `package_name`. Ordering should prefer stronger package-name matches first where practical, then fall back to recent activity. A later slice can replace this with a better ranking strategy without changing the frontend contract.

### `GET /api/v1/bindings/:packageName/authors/:author`

Returns one package-author group with release files included.

The response contains:

- `packageName`
- `author`
- `authorDisplayName`
- `libraryVersions`
- `rescriptVersions`
- `latestCreatedAt`
- `releases`

Each release contains:

- `id`
- `variantLabel`
- `variantSlug`
- `peerPackageRange`
- `rescriptRange`
- `description`
- `createdAt`
- `files`

Each file contains:

- `relativePath`
- `content`
- `sha256`
- `bytes`

If the group does not exist, the endpoint returns `404`.

## Frontend Routes

### `GET /`

Renders the homepage.

The page includes:

- a search form at the top
- a table below the form

If `q` is absent or blank, the Worker calls `/api/v1/bindings/recent` and labels the table "Recently updated". If `q` is present, the Worker calls `/api/v1/bindings/search?q=...` and labels the table "Search results".

The table columns are:

- package name
- author
- library versions
- ReScript versions

The package name links to the detail page for that package-author group.

### `GET /packages/:packageName/authors/:author`

Renders the detail page for one package-author group.

The page includes:

- `h1` with the package name
- author text beneath the heading
- tabs above the code block, one per release
- a plain `pre` and `code` block showing the selected release source

Tabs are server-side links for v1. Selecting a tab reloads the page with `?release=<release-id>`. The default selected release is the newest release in the group.

Tab labels use:

```text
<library version> / <ReScript version>
```

If two releases would have the same label, include the variant label to make the tabs distinguishable.

For multi-file releases, the code block concatenates files in `relativePath` order with a small path separator before each file.

## Rendering Strategy

The first implementation should try Xote SSR using the current Xote SSR API. Xote exposes `SSR.renderDocument` and `SSR.renderToString` for rendering `View.node` trees to HTML strings, plus hydration modules for client-side behavior. The v1 pages do not require hydration because search and tabs can use normal links and forms.

If SSR fails because of Worker compatibility, packaging, or missing runtime assumptions, keep the API contracts and page design intact but switch `packages/web` to a client-rendered Xote app. In that fallback, the Worker serves a simple HTML shell with the Pico CDN link, and browser-side Xote fetches the same public API endpoints.

## Styling

Use Pico CSS from the CDN in the document head. The pages should lean on semantic HTML:

- `main class="container"`
- `form` and `input type="search"` for search
- `table`, `thead`, `tbody`, `th`, and `td` for results
- `nav` or a simple link row for release tabs
- `pre` and `code` for binding source

Only add small local CSS if necessary for table wrapping, selected tab state, or code block readability.

## Error Handling

The frontend Worker should render small, plain pages for:

- registry API request failures
- empty recent/search results
- missing package-author details

The registry API should return JSON errors for invalid query/path input and `404` for missing details.

## Testing And Verification

Registry API tests should cover:

- recent results grouped by package and author
- fuzzy search matching package-name substrings
- distinct library and ReScript version aggregation
- package-author detail returning only that group and including files
- missing package-author detail returning `404`

Web Worker tests should cover:

- `/` rendering the search form and recent table
- `/?q=react` rendering search results
- detail route rendering `h1`, author, tabs, and selected source
- missing detail rendering a simple `404` page

Verification should run:

```bash
pnpm build
pnpm test
```

If a local Worker server is started during implementation, also verify the rendered homepage and one detail page with `curl` or a browser check.

## Documentation Sources Checked

- Xote README and source modules from `brnrdog/xote`, including `SSR.res`, `Hydration.res`, and `SSRState.res`.
- Pico CSS docs for semantic forms, tables, containers, and code blocks.
- Cloudflare Workers docs for Worker routing and static asset behavior.
