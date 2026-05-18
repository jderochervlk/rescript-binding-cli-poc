let picoCdn = "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"
let highlightCssCdn = "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.11.1/styles/github.min.css"
let highlightJsCdn = "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.11.1/highlight.min.js"
let highlightRescriptCdn = "https://unpkg.com/highlightjs-rescript@0.2.2/dist/rescript.min.js"

@val external encodeURIComponent: string => string = "encodeURIComponent"

let attr = View.Attr.string

let el = (tag, ~attrs=[], ~children=[], ()) => View.element(tag, ~attrs, ~children, ())

let linkForEntry = (entry: RegistryClient.entry) =>
  "/packages/" ++ encodeURIComponent(entry.packageName) ++ "/authors/" ++ encodeURIComponent(entry.author)

let selectedRelease = (
  releases: array<RegistryClient.detailRelease>,
  ~releaseId: option<string>,
) => {
  let selected = ref(None)
  for index in 0 to releases->Array.length - 1 {
    switch (selected.contents, releases[index], releaseId) {
    | (None, Some(release), Some(releaseId)) if release.id == releaseId =>
      selected := Some(release)
    | _ => ()
    }
  }

  switch (selected.contents, releases[0]) {
  | (Some(release), _) => Some(release)
  | (None, Some(release)) => Some(release)
  | (None, None) => None
  }
}

let searchForm = (~query="") =>
  el("form", ~attrs=[attr("method", "get"), attr("action", "/")], ~children=[
    el("input", ~attrs=[
      attr("type", "search"),
      attr("name", "q"),
      attr("value", query),
      attr("placeholder", "Search package names"),
    ], ()),
    el("button", ~attrs=[attr("type", "submit")], ~children=[View.text("Search")], ()),
  ], ())

let entryTable = entries =>
  if entries->Array.length == 0 {
    el("p", ~children=[View.text("No bindings found.")], ())
  } else {
    el("table", ~children=[
      el("thead", ~children=[
        el("tr", ~children=[
          el("th", ~children=[View.text("Package name")], ()),
          el("th", ~children=[View.text("Author")], ()),
          el("th", ~children=[View.text("Library versions")], ()),
          el("th", ~children=[View.text("ReScript versions")], ()),
        ], ()),
      ], ()),
      el("tbody", ~children=entries->Array.map((entry: RegistryClient.entry) =>
        el("tr", ~children=[
          el("td", ~children=[
            el("a", ~attrs=[attr("href", linkForEntry(entry))], ~children=[View.text(entry.packageName)], ()),
          ], ()),
          el("td", ~children=[View.text(entry.authorDisplayName)], ()),
          el("td", ~children=[View.text(entry.libraryVersions->Array.join(", "))], ()),
          el("td", ~children=[View.text(entry.rescriptVersions->Array.join(", "))], ()),
        ], ())
      ), ()),
    ], ())
  }

let listPage = (~title, ~query="", ~entries) => () =>
  el("main", ~attrs=[attr("class", "container")], ~children=[
    View.element("h1", ~children=[View.text("ReScript Bindings")], ()),
    searchForm(~query),
    el("h2", ~children=[View.text(title)], ()),
    entryTable(entries),
  ], ())

let home = listPage(~title="Recently updated", ~entries=[])

let releaseHref = (detail: RegistryClient.detail, release: RegistryClient.detailRelease) =>
  "/packages/"
  ++ encodeURIComponent(detail.packageName)
  ++ "/authors/"
  ++ encodeURIComponent(detail.author)
  ++ "?release="
  ++ encodeURIComponent(release.id)

let hasDuplicateRange = (releases: array<RegistryClient.detailRelease>, release: RegistryClient.detailRelease) => {
  let count = ref(0)
  for index in 0 to releases->Array.length - 1 {
    switch releases[index] {
    | Some(candidate)
        if candidate.peerPackageRange == release.peerPackageRange &&
          candidate.rescriptRange == release.rescriptRange =>
      count := count.contents + 1
    | _ => ()
    }
  }
  count.contents > 1
}

let releaseLabel = (releases: array<RegistryClient.detailRelease>, release: RegistryClient.detailRelease) => {
  let label = release.peerPackageRange ++ " / " ++ release.rescriptRange
  if hasDuplicateRange(releases, release) {
    label ++ " (" ++ release.variantLabel ++ ")"
  } else {
    label
  }
}

let releaseTabs = (~detail: RegistryClient.detail, ~selected: RegistryClient.detailRelease) =>
  el("nav", ~children=[
    el("ul", ~children=detail.releases->Array.map((release: RegistryClient.detailRelease) =>
      el("li", ~children=[
        el(
          "a",
          ~attrs=[
            attr("href", releaseHref(detail, release)),
            attr("aria-current", if release.id == selected.id {"page"} else {"false"}),
          ],
          ~children=[
            View.text(releaseLabel(detail.releases, release)),
          ],
          (),
        ),
      ], ())
    ), ()),
  ], ())

let sourceForFiles = (files: array<RegistryClient.file>) =>
  files
  ->Array.map((file: RegistryClient.file) => "/* " ++ file.relativePath ++ " */\n" ++ file.content)
  ->Array.join("\n\n")

let detailPage = (
  ~detail: RegistryClient.detail,
  ~releaseId: option<string>,
) => () =>
  switch selectedRelease(detail.releases, ~releaseId) {
  | None =>
    el("main", ~attrs=[attr("class", "container")], ~children=[
      el("h1", ~children=[View.text(detail.packageName)], ()),
      el("p", ~children=[View.text("No releases found.")], ()),
    ], ())
  | Some(selected) =>
    el("main", ~attrs=[attr("class", "container")], ~children=[
      el("p", ~children=[
        el("a", ~attrs=[attr("href", "/")], ~children=[View.text("All bindings")], ()),
      ], ()),
      el("h1", ~children=[View.text(detail.packageName)], ()),
      el("p", ~children=[View.text("Published by " ++ detail.authorDisplayName)], ()),
      releaseTabs(~detail, ~selected),
      el("h2", ~children=[View.text(selected.variantLabel)], ()),
      el("p", ~children=[
        View.text("Library " ++ selected.peerPackageRange ++ " / ReScript " ++ selected.rescriptRange),
      ], ()),
      el("p", ~children=[View.text(selected.description->Nullable.getOr(""))], ()),
      el("pre", ~children=[
        el("code", ~attrs=[attr("class", "language-rescript")], ~children=[
          View.text(sourceForFiles(selected.files)),
        ], ()),
      ], ()),
    ], ())
  }

let messagePage = (~title, ~message) => () =>
  el("main", ~attrs=[attr("class", "container")], ~children=[
    el("h1", ~children=[View.text(title)], ()),
    el("p", ~children=[View.text(message)], ()),
  ], ())

let document = (~title: string, body: unit => View.node) =>
  SSR.renderDocument(
    ~head=`<title>${SSR.Html.escape(title)}</title><meta name="color-scheme" content="light dark" /><script src="${SSR.Html.escape(highlightJsCdn)}"></script><script src="${SSR.Html.escape(highlightRescriptCdn)}"></script><script>hljs.highlightAll();</script>`,
    ~styles=[picoCdn, highlightCssCdn],
    body,
  )
