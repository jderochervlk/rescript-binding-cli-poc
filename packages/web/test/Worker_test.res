type request
type response
type responseInit
type textResponse

@new external makeRequest: string => Worker.request = "Request"
@get external responseStatus: Worker.response => int = "status"
@send external responseText: Worker.response => promise<string> = "text"
@send external includes: (string, string) => bool = "includes"

let emptyEnv: Worker.env = %raw(`({ REGISTRY_API_BASE: "https://registry.test/api" })`)
let serviceEnv: Worker.env = %raw(`({
  REGISTRY_API_BASE: "https://registry.test/api",
  REGISTRY_API: {
    fetch: async request => {
      const url = typeof request === "string" ? request : request.url;
      if (url === "https://registry.internal/api/v1/bindings/recent") {
        return new Response('{"entries":[{"packageName":"service-bound","author":"jane","authorDisplayName":"Jane Example","libraryVersions":["^1.0.0"],"rescriptVersions":["^12.0.0"],"latestCreatedAt":"2026-05-06T12:00:00Z","releases":[{"id":"service-1","packageName":"service-bound","variantLabel":"Default","variantSlug":"default","peerPackageRange":"^1.0.0","rescriptRange":"^12.0.0","description":null,"createdAt":"2026-05-06T12:00:00Z"}]}]}', { status: 200, headers: [["content-type", "application/json"]] })
      }
      return new Response('{"error":"Unexpected service URL"}', { status: 500, headers: [["content-type", "application/json"]] })
    }
  }
})`)
let ctx = %raw(`({})`)

let json = (~status=200, body) =>
  Worker.makeResponse(body, Worker.responseInit(
    ~status,
    ~headers=[["content-type", "application/json"]],
    (),
  ))

let fakeFetcher = async url => {
  if url == "https://registry.test/api/v1/bindings/recent" {
    json(`{"entries":[{"packageName":"@scope/recent","author":"jane","authorDisplayName":"Jane Example","libraryVersions":["^18.0.0"],"rescriptVersions":["^11.0.0"],"latestCreatedAt":"2026-05-01T12:00:00Z","releases":[{"id":"recent-1","packageName":"@scope/recent","variantLabel":"Default","variantSlug":"default","peerPackageRange":"^18.0.0","rescriptRange":"^11.0.0","description":"Recent binding","createdAt":"2026-05-01T12:00:00Z"}]}]}`)
  } else if url == "https://registry.test/api/v1/bindings/search?q=react" {
    json(`{"entries":[{"packageName":"react","author":"jane","authorDisplayName":"Jane Example","libraryVersions":["^18.0.0"],"rescriptVersions":["^11.0.0"],"latestCreatedAt":"2026-05-02T12:00:00Z","releases":[{"id":"search-1","packageName":"react","variantLabel":"Default","variantSlug":"default","peerPackageRange":"^18.0.0","rescriptRange":"^11.0.0","description":"React bindings","createdAt":"2026-05-02T12:00:00Z"}]}]}`)
  } else if url == "https://registry.test/api/v1/bindings/react/authors/jane" {
    json(`{"packageName":"react","author":"jane","authorDisplayName":"Jane Example","libraryVersions":["^18.0.0","^19.0.0"],"rescriptVersions":["^11.0.0","^12.0.0"],"latestCreatedAt":"2026-05-03T12:00:00Z","releases":[{"id":"detail-1","packageName":"react","variantLabel":"Default","variantSlug":"default","peerPackageRange":"^18.0.0","rescriptRange":"^11.0.0","description":null,"createdAt":"2026-05-03T12:00:00Z","files":[{"relativePath":"React.res","content":"let unsafe = \\\"<script>\\\"","sha256":"abc","bytes":23},{"relativePath":"ReactDOM.res","content":"let render = () => ()","sha256":"ghi","bytes":19}]},{"id":"detail-2","packageName":"react","variantLabel":"Experimental","variantSlug":"experimental","peerPackageRange":"^19.0.0","rescriptRange":"^12.0.0","description":"Next React bindings","createdAt":"2026-05-04T12:00:00Z","files":[{"relativePath":"ReactNext.res","content":"let selected = true","sha256":"def","bytes":19}]},{"id":"detail-3","packageName":"react","variantLabel":"Alt","variantSlug":"alt","peerPackageRange":"^18.0.0","rescriptRange":"^11.0.0","description":"Alternate React bindings","createdAt":"2026-05-05T12:00:00Z","files":[{"relativePath":"ReactAlt.res","content":"let alt = true","sha256":"jkl","bytes":14}]}]}`)
  } else if url == "https://registry.test/api/v1/bindings/missing/authors/nobody" {
    json(~status=404, `{"error":"Binding author detail not found"}`)
  } else {
    json(~status=500, `{"error":"Unexpected URL ${url}"}`)
  }
}

let invalidJsonFetcher = async _url => json(`not json`)

let rejectedFetcher = async _url => {
  throw(Failure("upstream fetch failed"))
}

let upstreamNotFoundFetcher = async _url => json(~status=404, `{"error":"Not found"}`)

let assertContains = (html, text, label) =>
  TestSupport.assertTrue(html->includes(text), label)

let assertStatus = (response, expected, label) =>
  TestSupport.assertTrue(response->responseStatus == expected, label)

let run = async () => {
  let recentResponse = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/"), emptyEnv, ctx)
  recentResponse->assertStatus(200, "recent homepage returns success")
  let recentHtml = await recentResponse->responseText
  recentHtml->assertContains("<!DOCTYPE html>", "recent homepage renders a document")
  recentHtml->assertContains("picocss", "recent homepage includes Pico CDN")
  recentHtml->assertContains("highlight.js", "recent homepage includes Highlight.js CDN")
  recentHtml->assertContains("highlightjs-rescript", "recent homepage includes ReScript grammar CDN")
  recentHtml->assertContains("hljs.highlightAll()", "recent homepage initializes Highlight.js")
  recentHtml->assertContains("Recently updated", "recent homepage uses approved heading")
  recentHtml->assertContains("Package name", "recent homepage uses approved table header")
  recentHtml->assertContains("Library versions", "recent homepage uses approved library header")
  recentHtml->assertContains("@scope/recent", "recent homepage renders API entries")
  recentHtml->assertContains("Jane Example", "recent homepage renders author display name")

  let serviceResponse = await Worker.fetch(makeRequest("https://web.test/"), serviceEnv, ctx)
  serviceResponse->assertStatus(200, "public fetch uses registry service binding")
  let serviceHtml = await serviceResponse->responseText
  serviceHtml->assertContains("service-bound", "service binding renders API entries")

  let searchResponse = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/?q=react"), emptyEnv, ctx)
  searchResponse->assertStatus(200, "search homepage returns success")
  let searchHtml = await searchResponse->responseText
  searchHtml->assertContains("Search results", "search renders approved heading")
  searchHtml->assertContains("react", "search renders API result package")

  let detailResponse = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/packages/react/authors/jane"), emptyEnv, ctx)
  detailResponse->assertStatus(200, "detail page returns success")
  let detailHtml = await detailResponse->responseText
  detailHtml->assertContains("<h1>react</h1>", "detail page renders package heading")
  detailHtml->assertContains("Jane Example", "detail page renders author")
  detailHtml->assertContains("^18.0.0 / ^11.0.0 (Default)", "detail page renders duplicate range tab with variant")
  detailHtml->assertContains("?release=detail-2", "detail page links tabs by release id")
  detailHtml->assertContains("/* React.res */", "detail page renders file separator")
  detailHtml->assertContains("/* ReactDOM.res */", "detail page combines files in one source block")
  detailHtml->assertContains("class=\"language-rescript\"", "detail page marks binding source as ReScript")
  detailHtml->assertContains("&lt;script&gt;", "detail page escapes source code")

  let selectedResponse = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/packages/react/authors/jane?release=detail-2"), emptyEnv, ctx)
  selectedResponse->assertStatus(200, "selected release page returns success")
  let selectedHtml = await selectedResponse->responseText
  selectedHtml->assertContains("^19.0.0 / ^12.0.0", "selected release tab renders approved label")
  selectedHtml->assertContains("let selected = true", "selected release renders selected source")

  let missingResponse = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/packages/missing/authors/nobody"), emptyEnv, ctx)
  missingResponse->assertStatus(404, "missing detail maps to 404")
  let missingHtml = await missingResponse->responseText
  missingHtml->assertContains("Binding not found", "missing detail renders approved not found page")

  let malformedResponse = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/packages/%E0%A4%A/authors/jane"), emptyEnv, ctx)
  malformedResponse->assertStatus(404, "malformed detail path maps to 404")
  let malformedHtml = await malformedResponse->responseText
  malformedHtml->assertContains("Binding not found", "malformed detail path renders not found page")

  let invalidJsonResponse = await Worker.fetchWith(~fetcher=invalidJsonFetcher, makeRequest("https://web.test/"), emptyEnv, ctx)
  invalidJsonResponse->assertStatus(502, "invalid JSON maps to 502")
  let invalidJsonHtml = await invalidJsonResponse->responseText
  invalidJsonHtml->assertContains("Registry unavailable", "invalid JSON renders registry unavailable page")

  let rejectedFetchResponse = await Worker.fetchWith(~fetcher=rejectedFetcher, makeRequest("https://web.test/"), emptyEnv, ctx)
  rejectedFetchResponse->assertStatus(502, "rejected fetch maps to 502")
  let rejectedFetchHtml = await rejectedFetchResponse->responseText
  rejectedFetchHtml->assertContains("Registry unavailable", "rejected fetch renders registry unavailable page")

  let recentNotFoundResponse = await Worker.fetchWith(~fetcher=upstreamNotFoundFetcher, makeRequest("https://web.test/"), emptyEnv, ctx)
  recentNotFoundResponse->assertStatus(502, "recent upstream 404 maps to 502")
  let recentNotFoundHtml = await recentNotFoundResponse->responseText
  recentNotFoundHtml->assertContains("Registry unavailable", "recent upstream 404 renders registry unavailable page")

  let searchNotFoundResponse = await Worker.fetchWith(~fetcher=upstreamNotFoundFetcher, makeRequest("https://web.test/?q=missing"), emptyEnv, ctx)
  searchNotFoundResponse->assertStatus(502, "search upstream 404 maps to 502")
  let searchNotFoundHtml = await searchNotFoundResponse->responseText
  searchNotFoundHtml->assertContains("Registry unavailable", "search upstream 404 renders registry unavailable page")

  Console.log("Web Worker_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(TestSupport.messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
