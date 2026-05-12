type request
type response = RegistryClient.response
type responseInit
type env
type ctx
type url
type searchParams
type service

type fetcher = RegistryClient.fetcher

@new external makeUrl: string => url = "URL"
@new external makeServiceRequest: string => request = "Request"
@get external requestUrl: request => string = "url"
@get external urlPathname: url => string = "pathname"
@get external urlSearch: url => string = "search"
@get external urlSearchParams: url => searchParams = "searchParams"
@return(nullable) @send external searchParamGet: (searchParams, string) => option<string> = "get"
@get external registryApiBase: env => option<string> = "REGISTRY_API_BASE"
@send external serviceFetch: (service, request) => promise<response> = "fetch"
@new external makeResponseExternal: (string, responseInit) => response = "Response"
@obj external responseInitExternal: (~status: int, ~headers: array<array<string>>, unit) => responseInit = ""
@val external globalFetch: fetcher = "fetch"
@send external split: (string, string) => array<string> = "split"
@val external decodeURIComponent: string => string = "decodeURIComponent"

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

let hasRegistryApiService = env => {
  let _ = env
  %raw(`env.REGISTRY_API != null`)
}

let registryApiService = env => {
  let _ = env
  %raw(`env.REGISTRY_API`)
}

let registryFetcher = env =>
  if env->hasRegistryApiService {
    let service = env->registryApiService
    url => {
      let serviceUrl = makeUrl(url)
      service->serviceFetch(makeServiceRequest(
        "https://registry.internal" ++ serviceUrl->urlPathname ++ serviceUrl->urlSearch,
      ))
    }
  } else {
    globalFetch
  }

let getAt = (items: array<'a>, index: int): option<'a> =>
  if index < 0 || index >= items->Array.length {
    None
  } else {
    items[index]
  }

let decodePathSegment = segment =>
  try {
    Some(decodeURIComponent(segment))
  } catch {
  | _ => None
  }

let notFound = () =>
  html(~status=404, Pages.document(
    ~title="Binding not found",
    Pages.messagePage(~title="Binding not found", ~message="The requested binding could not be found."),
  ))

let badGateway = message =>
  html(~status=502, Pages.document(
    ~title="Registry unavailable",
    Pages.messagePage(~title="Registry unavailable", ~message),
  ))

let listResponse = async (~fetcher, ~env, ~query) => {
  switch query {
  | Some(query) if query != "" =>
    switch await RegistryClient.search(~fetcher, ~apiBase=apiBase(env), ~query) {
    | Ok(entries) =>
      html(Pages.document(
        ~title="Search results",
        Pages.listPage(~title="Search results", ~query, ~entries),
      ))
    | Error(NotFound) => badGateway("Registry API search endpoint is unavailable")
    | Error(Upstream(message)) => badGateway(message)
    }
  | _ =>
    switch await RegistryClient.recent(~fetcher, ~apiBase=apiBase(env)) {
    | Ok(entries) =>
      html(Pages.document(
        ~title="ReScript Bindings",
        Pages.listPage(~title="Recently updated", ~entries),
      ))
    | Error(NotFound) => badGateway("Registry API recent endpoint is unavailable")
    | Error(Upstream(message)) => badGateway(message)
    }
  }
}

let detailResponse = async (~fetcher, ~env, ~packageName, ~author, ~url) => {
  let searchParams = url->urlSearchParams
  let releaseId = searchParams->searchParamGet("release")
  switch await RegistryClient.detail(
    ~fetcher,
    ~apiBase=apiBase(env),
    ~packageName,
    ~author,
  ) {
  | Ok(detail) =>
    html(Pages.document(
      ~title=detail.packageName,
      Pages.detailPage(~detail, ~releaseId),
    ))
  | Error(NotFound) => notFound()
  | Error(Upstream(message)) => badGateway(message)
  }
}

let fetchWith = async (~fetcher: fetcher, request, env, _ctx) => {
  let url = makeUrl(request->requestUrl)
  switch url->urlPathname {
  | "/" => await listResponse(
      ~fetcher,
      ~env,
      ~query=url->urlSearchParams->searchParamGet("q"),
    )
  | pathname =>
    let parts = pathname->split("/")
    switch (parts->getAt(1), parts->getAt(2), parts->getAt(3), parts->getAt(4)) {
    | (Some("packages"), Some(packageName), Some("authors"), Some(author)) =>
      switch (decodePathSegment(packageName), decodePathSegment(author)) {
      | (Some(packageName), Some(author)) =>
        await detailResponse(
          ~fetcher,
          ~env,
          ~packageName,
          ~author,
          ~url,
        )
      | _ => notFound()
      }
    | _ => notFound()
    }
  }
}

let workerFetch = async (request, env, ctx) => await fetchWith(~fetcher=registryFetcher(env), request, env, ctx)

let fetch = workerFetch

%%raw("export default { fetch: workerFetch }")
