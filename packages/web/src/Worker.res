type request
type response
type responseInit
type env
type ctx
type url

type fetcher = string => promise<response>

@new external makeUrl: string => url = "URL"
@get external requestUrl: request => string = "url"
@get external urlPathname: url => string = "pathname"
@get external registryApiBase: env => option<string> = "REGISTRY_API_BASE"
@new external makeResponseExternal: (string, responseInit) => response = "Response"
@obj external responseInitExternal: (~status: int, ~headers: array<array<string>>, unit) => responseInit = ""
@val external globalFetch: fetcher = "fetch"

let makeResponse = (body, init) => makeResponseExternal(body, init)
let responseInit = (~status: int, ~headers: array<array<string>>, ()) =>
  responseInitExternal(~status, ~headers, ())

let html = (~status=200, body) =>
  makeResponse(body, responseInit(
    ~status,
    ~headers=[["content-type", "text/html; charset=utf-8"]],
    (),
  ))

let apiBase = env =>
  env->registryApiBase->Belt.Option.getWithDefault("https://rescript-binding-registry.josh-401.workers.dev/api")

let fetchWith = async (~fetcher: fetcher, request, env, _ctx) => {
  let _ = fetcher
  let _ = apiBase(env)
  let url = makeUrl(request->requestUrl)
  switch url->urlPathname {
  | "/" => html(Pages.document(~title="ReScript Bindings", Pages.home))
  | _ => html(~status=404, Pages.document(~title="Not found", () =>
      View.element("main", ~attrs=[View.Attr.string("class", "container")], ~children=[
        View.element("h1", ~children=[View.text("Not found")], ()),
      ], ())
    ))
  }
}

let fetch = async (request, env, ctx) => await fetchWith(~fetcher=globalFetch, request, env, ctx)

%%raw("export default { fetch }")
