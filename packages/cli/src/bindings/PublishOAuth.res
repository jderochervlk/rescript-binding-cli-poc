open RegistryTypes

type cacheInput
type openOptions
type oauthCallbackInput
type options
type deps
type fetchInit
type headersInit
type metadata
type clientRegistration
type tokenResponse
type tokenBundle
type session = {
  identity: PublishAuthTypes.authIdentity,
  accessToken: string,
}
type loopbackServer
type loopbackInput
type callback
type childProcess
type spawnOptions
type httpServer
type httpRequest
type httpResponse
type serverAddress
type errorPayload
type spawnImpl = (string, array<string>, spawnOptions) => childProcess
type input
type output
type promptInput
type readline
type readlineOptions
type searchConfig
type searchChoice
type identityPayload
type promptContext
type url
type searchParams
type readDirent
type publishedRelease = {
  id: string,
  packageName: string,
  variantLabel: string,
  peerPackageRange: string,
  rescriptRange: string,
  createdAt: string,
}
type publishedReleaseListPayload = {releases: option<array<publishedRelease>>}
type deleteReleaseResult = {
  releaseId: string,
  packageName: string,
  peerPackageRange: string,
  rescriptRange: string,
  deleted: bool,
}

type fetchImpl = (string, fetchInit) => promise<WebFetch.response>
type logImpl = string => unit
type nowImpl = unit => float
type readCacheImpl = string => promise<option<tokenBundle>>
type writeCacheImpl = (string, tokenBundle) => promise<unit>
type openBrowserImpl = string => promise<unit>
type createLoopbackServerImpl = loopbackInput => promise<loopbackServer>
type stringFactory = unit => string
type codeChallengeImpl = string => string
type promptForPublishInputImpl = promptInput => promise<option<publishInput>>
type selectDeleteReleaseImpl = (array<publishedRelease>, bool, input, output) => promise<option<publishedRelease>>
type confirmDeleteReleaseImpl = (publishedRelease, input, output) => promise<bool>
type completer = string => (array<string>, string)

@module("node:child_process") external defaultSpawn: spawnImpl = "spawn"
@module("node:crypto") external createHash: string => 'hash = "createHash"
@send external hashUpdate: ('hash, string) => 'hash = "update"
@send external hashDigest: ('hash, string) => string = "digest"
@module("node:crypto") external randomBytes: int => 'buffer = "randomBytes"
@send external bufferToString: ('buffer, string) => string = "toString"
@module("node:os") external homedir: unit => string = "homedir"
@module("node:process") external platform: string = "platform"
@module("node:process") external stdin: input = "stdin"
@module("node:process") external stdout: output = "stdout"
@module("node:process") external cwd: unit => string = "cwd"
@module("node:readline/promises")
external createInterface: readlineOptions => readline = "createInterface"
@module("node:http")
external createHttpServer: ((httpRequest, httpResponse) => unit) => httpServer = "createServer"
@module("node:fs")
external readdirSync: (string, NodeFs.readdirOptions) => array<NodeFs.dirent> = "readdirSync"
@module("node:fs") external statSync: string => NodeFs.stats = "statSync"
@scope("Date") @val external dateNow: unit => float = "now"
@scope("JSON") @val external parseJson: string => 'a = "parse"
@scope("JSON") @val external stringify: 'a => string = "stringify"
@val @scope("globalThis") external globalFetch: option<fetchImpl> = "fetch"
@val external encodeURIComponent: string => string = "encodeURIComponent"
@send external responseJsonAs: WebFetch.response => promise<'payload> = "json"
@new external makeUrl: string => url = "URL"
@new external makeUrlWithBase: (string, string) => url = "URL"
@get external urlHostname: url => string = "hostname"
@get external urlPathname: url => string = "pathname"
@get external urlSearchParams: url => searchParams = "searchParams"
@set external setUrlPathname: (url, string) => unit = "pathname"
@set external setUrlSearch: (url, string) => unit = "search"
@set external setUrlHash: (url, string) => unit = "hash"
@send external urlToString: url => string = "toString"
@send external searchParamsSet: (searchParams, string, string) => unit = "set"
@return(nullable) @send external searchParamsGet: (searchParams, string) => option<string> = "get"
@send external searchParamsToString: searchParams => string = "toString"
@send external trim: string => string = "trim"
@send external toLowerCase: string => string = "toLowerCase"
@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external includesString: (string, string) => bool = "includes"
@send external indexOfFrom: (string, string, int) => int = "indexOf"
@send external sliceFromTo: (string, int, int) => string = "slice"
@send external startsWith: (string, string) => bool = "startsWith"
@send external endsWith: (string, string) => bool = "endsWith"
@send external localeCompare: (string, string) => int = "localeCompare"
@send external sortInPlaceWith: (array<'a>, ('a, 'a) => int) => unit = "sort"
@send external question: (readline, string) => promise<string> = "question"
@send external closeReadline: readline => unit = "close"
@return(nullable) @get external httpRequestUrl: httpRequest => option<string> = "url"
@set external setHttpStatusCode: (httpResponse, int) => unit = "statusCode"
@send external endHttpResponse: (httpResponse, string) => unit = "end"
@send external httpServerOnceError: (httpServer, string, exn => unit) => httpServer = "once"
@send external httpServerListen: (httpServer, int, string, unit => unit) => httpServer = "listen"
@return(nullable) @send external httpServerAddress: httpServer => option<serverAddress> = "address"
@send external httpServerClose: (httpServer, Nullable.t<exn> => unit) => httpServer = "close"
@get external serverAddressPort: serverAddress => int = "port"
@get external inputIsTty: input => option<bool> = "isTTY"
@get external outputIsTty: output => option<bool> = "isTTY"
@get external jsErrorStatus: JsExn.t => option<int> = "status"
@get external jsErrorPayload: JsExn.t => option<errorPayload> = "payload"
@new external makeJsError: string => exn = "Error"
@set external setErrorStatus: (exn, int) => unit = "status"
@set external setErrorPayload: (exn, option<errorPayload>) => unit = "payload"

@obj external emptyFetchInit: unit => fetchInit = ""
@obj external emptyDeps: unit => deps = ""
@obj external emptyPackageJson: unit => PackageJson.packageJson = ""
@obj external spawnOptions: (~stdio: string, unit) => spawnOptions = ""
@obj external jsonHeadersObj: (@as("Content-Type") ~contentType: string, unit) => headersInit = ""
@obj external authHeadersObj: (@as("Authorization") ~authorization: string, unit) => headersInit = ""
@obj
external publishHeadersObj: (
  @as("Authorization") ~authorization: string,
  @as("Content-Type") ~contentType: string,
  unit,
) => headersInit = ""
@obj external getDiscoveryFetchInit: (~method: string, ~redirect: string, unit) => fetchInit = ""
@obj
external postFetchInit: (~method: string, ~headers: headersInit, ~body: string, unit) => fetchInit =
  ""
@obj external deleteFetchInit: (~method: string, ~headers: headersInit, unit) => fetchInit = ""
@obj external getAuthFetchInit: (~method: string, ~headers: headersInit, unit) => fetchInit = ""
@obj external readlineOptions: (~input: input, ~output: output, unit) => readlineOptions = ""
@obj
external readlineOptionsWithCompleter: (
  ~input: input,
  ~output: output,
  ~completer: completer,
  unit,
) => readlineOptions = ""
@obj external searchChoice: (~name: string, ~value: string, unit) => searchChoice = ""
@obj
external searchConfig: (
  ~message: string,
  ~pageSize: int,
  ~source: (option<string>, 'context) => promise<array<searchChoice>>,
  unit,
) => searchConfig = ""
@obj external promptContext: (~input: input, ~output: output, unit) => promptContext = ""
@obj external loopbackInput: (~expectedState: string, unit) => loopbackInput = ""
@obj external oauthCallbackInputObj: (~callbackUrl: url, ~expectedState: string, unit) => oauthCallbackInput = ""
@obj external loopbackCallbackObj: (~code: string, ~state: string, unit) => callback = ""
@obj
external tokenBundleObj: (
  ~accessToken: string,
  ~refreshToken: option<string>,
  ~expiresAt: float,
  ~tokenEndpoint: string,
  ~authorizationEndpoint: string,
  ~registrationEndpoint: string,
  ~clientId: string,
  ~resource: string,
  ~publishBaseUrl: string,
  unit,
) => tokenBundle = ""
@obj
external loopbackServerObj: (
  ~redirectUri: string,
  ~waitForCode: unit => promise<callback>,
  ~close: unit => promise<unit>,
  unit,
) => loopbackServer = ""
@obj
external cacheInputObj: (
  ~platform: string,
  ~homeDir: string,
  ~hostname: string,
  unit,
) => cacheInput = ""
@obj
external promptInputObj: (~cwd: string, ~stdin: input, ~stdout: output, unit) => promptInput = ""

@get external cachePlatform: cacheInput => option<string> = "platform"
@get external cacheHomeDir: cacheInput => option<string> = "homeDir"
@get external cacheHostname: cacheInput => option<string> = "hostname"
@get external openPlatform: openOptions => option<string> = "platform"
@get external openSpawn: openOptions => option<spawnImpl> = "spawn"
@get external openLog: openOptions => option<logImpl> = "log"
@get external callbackUrl: oauthCallbackInput => url = "callbackUrl"
@get external callbackExpectedState: oauthCallbackInput => string = "expectedState"
@get external loopbackExpectedState: loopbackInput => string = "expectedState"
@get external optionsDeps: options => option<deps> = "deps"
@get external depFetch: deps => option<fetchImpl> = "fetch"
@get external depNow: deps => option<nowImpl> = "now"
@get external depPlatform: deps => option<string> = "platform"
@get external depHomeDir: deps => option<string> = "homeDir"
@get external depReadCache: deps => option<readCacheImpl> = "readCache"
@get external depWriteCache: deps => option<writeCacheImpl> = "writeCache"
@get external depOpenBrowser: deps => option<openBrowserImpl> = "openBrowser"
@get
external depCreateLoopbackServer: deps => option<createLoopbackServerImpl> = "createLoopbackServer"
@get external depRandomString: deps => option<stringFactory> = "randomString"
@get external depCodeVerifier: deps => option<stringFactory> = "codeVerifier"
@get
external depCodeChallengeFromVerifier: deps => option<codeChallengeImpl> =
  "codeChallengeFromVerifier"
@get
external depPromptForPublishInput: deps => option<promptForPublishInputImpl> =
  "promptForPublishInput"
@get
external depSelectDeleteRelease: deps => option<selectDeleteReleaseImpl> = "selectDeleteRelease"
@get
external depConfirmDeleteRelease: deps => option<confirmDeleteReleaseImpl> =
  "confirmDeleteRelease"
@get external depCwd: deps => option<string> = "cwd"
@get external depStdin: deps => option<input> = "stdin"
@get external depStdout: deps => option<output> = "stdout"
@get external promptInputCwd: promptInput => string = "cwd"
@get external promptInputStdin: promptInput => input = "stdin"
@get external promptInputStdout: promptInput => output = "stdout"
@get external tokenAccessToken: tokenBundle => option<string> = "accessToken"
@get external tokenRefreshToken: tokenBundle => option<string> = "refreshToken"
@get external tokenExpiresAt: tokenBundle => option<float> = "expiresAt"
@get external tokenClientId: tokenBundle => option<string> = "clientId"
@get external metadataAuthorizationEndpoint: metadata => string = "authorization_endpoint"
@get external metadataTokenEndpoint: metadata => string = "token_endpoint"
@get external metadataRegistrationEndpoint: metadata => string = "registration_endpoint"
@get external tokenResponseAccessToken: tokenResponse => string = "access_token"
@get external tokenResponseRefreshToken: tokenResponse => option<string> = "refresh_token"
@get external tokenResponseExpiresIn: tokenResponse => float = "expires_in"
@get external clientId: clientRegistration => string = "client_id"
@get external loopbackRedirectUri: loopbackServer => string = "redirectUri"
@send external loopbackWaitForCode: loopbackServer => promise<callback> = "waitForCode"
@send external loopbackClose: loopbackServer => promise<unit> = "close"
@get external callbackCode: callback => string = "code"
@get external errorPayloadError: errorPayload => option<string> = "error"
@get external errorPayloadMessage: errorPayload => option<string> = "message"
@get external choiceName: searchChoice => string = "name"
@return(nullable) @get
external identityPayloadGithubLogin: identityPayload => option<string> = "githubLogin"
@return(nullable) @get
external identityPayloadDisplayName: identityPayload => option<string> = "displayName"
@return(nullable) @get external identityPayloadEmail: identityPayload => option<string> = "email"
@get external publishResultDuplicate: 'result => bool = "duplicate"
@get external publishResultReleaseId: 'result => string = "releaseId"
@get external publishResultPackageName: 'result => string = "packageName"
@get external publishResultFileCount: 'result => int = "fileCount"

@module("@inquirer/prompts")
external search: (searchConfig, promptContext) => promise<string> = "search"
@send external childOnceError: (childProcess, string, exn => unit) => childProcess = "once"
@send external childOnceClose: (childProcess, string, int => unit) => childProcess = "once"

let publishBaseUrl = RegistryConfig.publishBaseUrl
let oauthResource = RegistryConfig.oauthResource

let jsonHeaders = (): headersInit => jsonHeadersObj(~contentType="application/json", ())
let formHeaders = (): headersInit =>
  jsonHeadersObj(~contentType="application/x-www-form-urlencoded", ())
let authHeaders = token => authHeadersObj(~authorization="Bearer " ++ token, ())
let publishHeaders = token =>
  publishHeadersObj(~authorization="Bearer " ++ token, ~contentType="application/json", ())

let fail = message => throw(makeJsError(message))

let throwJsError = error => JsExn.throw(error)

let rethrowCaught = error =>
  switch error->JsExn.fromException {
  | Some(jsError) => throwJsError(jsError)
  | None => throw(error)
  }

let depsFromOptions = (maybeOptions: option<options>) =>
  switch maybeOptions {
  | Some(options) => options->optionsDeps->Belt.Option.getWithDefault(emptyDeps())
  | None => emptyDeps()
  }

let joinPath = parts => parts->Array.join("/")

let cacheFilePathFor = input => {
  let hostname = switch input->cacheHostname {
  | Some(hostname) if hostname != "" => hostname
  | _ => fail("cacheFilePathFor requires a hostname")
  }
  let targetPlatform = input->cachePlatform->Belt.Option.getWithDefault(platform)
  let homeDir = input->cacheHomeDir->Belt.Option.getWithDefault(homedir())
  let normalizedHomeDir = homeDir->replaceAll("\\", "/")
  let filename = hostname ++ ".json"

  if targetPlatform == "darwin" {
    joinPath([
      normalizedHomeDir,
      "Library",
      "Application Support",
      "rescript-bindings",
      "oauth",
      filename,
    ])
  } else if targetPlatform == "win32" {
    joinPath([normalizedHomeDir, "rescript-bindings", "oauth", filename])
  } else {
    joinPath([normalizedHomeDir, ".local", "state", "rescript-bindings", "oauth", filename])
  }
}

let isAccessTokenUsableFromOption = (bundle, now) =>
  switch bundle {
  | Some(bundle) =>
    PublishTokenStrategy.isAccessTokenUsable(
      ~hasAccessToken=bundle->tokenAccessToken != None,
      ~expiresAt=bundle->tokenExpiresAt,
      ~now,
    )
  | None => false
  }

let isAccessTokenUsable = (bundle, now) => isAccessTokenUsableFromOption(Some(bundle), now)

let selectAuthStrategyFromOption = (bundle, now) =>
  PublishTokenStrategy.selectName(
    ~hasUsableAccessToken=isAccessTokenUsableFromOption(bundle, now),
    ~hasRefreshToken=switch bundle {
    | Some(bundle) => bundle->tokenRefreshToken != None
    | None => false
    },
  )

let selectAuthStrategy = (bundle, now) => selectAuthStrategyFromOption(Some(bundle), now)

let codeChallengeFromVerifier = verifier =>
  createHash("sha256")->hashUpdate(verifier)->hashDigest("base64url")

let defaultRandomString = () => randomBytes(24)->bufferToString("hex")
let defaultCodeVerifier = () => randomBytes(48)->bufferToString("base64url")

let defaultReadCache: readCacheImpl = async cachePath => {
  try {
    Some((await NodeFs.readFileUtf8(cachePath, "utf8"))->parseJson)
  } catch {
  | _ => None
  }
}

let defaultWriteCache = async (cachePath, bundle) => {
  await NodeFs.mkdirRecursive(NodePath.dirname(cachePath), {"recursive": true})
  await NodeFs.writeFileUtf8(cachePath, stringify(bundle), "utf8")
}

let browserOpenCommand = (targetPlatform, url) =>
  if targetPlatform == "darwin" {
    ("open", [url])
  } else if targetPlatform == "win32" {
    ("cmd", ["/c", "start", "", url])
  } else {
    ("xdg-open", [url])
  }

let waitForBrowserOpen = (spawnImpl, commandName, commandArgs) =>
  Promise.make((resolve, _reject) => {
    let child = spawnImpl(commandName, commandArgs, spawnOptions(~stdio="ignore", ()))
    child->childOnceError("error", _error => resolve(false))->ignore
    child->childOnceClose("close", code => resolve(code == 0))->ignore
  })

let defaultOpenBrowser = async (url, maybeOptions: option<openOptions>) => {
  let targetPlatform = switch maybeOptions {
  | Some(options) => options->openPlatform->Belt.Option.getWithDefault(platform)
  | None => platform
  }
  let spawnImpl = switch maybeOptions {
  | Some(options) => options->openSpawn->Belt.Option.getWithDefault(defaultSpawn)
  | None => defaultSpawn
  }
  let log = switch maybeOptions {
  | Some(options) => options->openLog->Belt.Option.getWithDefault(message => Console.log(message))
  | None => message => Console.log(message)
  }
  let (commandName, commandArgs) = browserOpenCommand(targetPlatform, url)
  let opened: bool = await waitForBrowserOpen(spawnImpl, commandName, commandArgs)

  if !opened {
    log("Could not open a browser automatically. Open this URL to continue:")
    log(url)
  }
}

let readOAuthCallback = input => {
  let callbackUrl = input->callbackUrl
  let searchParams = callbackUrl->urlSearchParams
  let code = searchParams->searchParamsGet("code")
  let state = searchParams->searchParamsGet("state")
  let error = searchParams->searchParamsGet("error")
  let errorDescription = searchParams->searchParamsGet("error_description")

  switch error {
  | Some(error) =>
    fail(
      switch errorDescription {
      | Some(description) => "OAuth callback error: " ++ error ++ ": " ++ description
      | None => "OAuth callback error: " ++ error
      },
    )
  | None => ()
  }

  switch (code, state) {
  | (Some(code), Some(state)) =>
    if state != input->callbackExpectedState {
      fail("OAuth state validation failed")
    }
    loopbackCallbackObj(~code, ~state, ())
  | _ =>
    let query = searchParams->searchParamsToString
    fail(
      if query != "" {
        "OAuth callback missing code or state. Callback query: " ++ query
      } else {
        "OAuth callback missing code or state. Callback query was empty."
      },
    )
  }
}

let defaultCreateLoopbackServer = async (input: loopbackInput) => {
  let expectedState = input->loopbackExpectedState
  let codeResult = Promise.withResolvers()
  let server = createHttpServer((request, response) => {
    let requestUrl = request->httpRequestUrl->Belt.Option.getWithDefault("/")
    let callbackUrl = makeUrlWithBase(requestUrl, "http://127.0.0.1")

    if callbackUrl->urlPathname != "/callback" {
      response->setHttpStatusCode(404)
      response->endHttpResponse("Not found")
    } else {
      try {
        let callback = readOAuthCallback(oauthCallbackInputObj(~callbackUrl, ~expectedState, ()))
        response->setHttpStatusCode(200)
        response->endHttpResponse("Authentication complete. You can return to the terminal.")
        codeResult.resolve(callback)
      } catch {
      | error =>
        response->setHttpStatusCode(400)
        let message = switch error->JsExn.fromException {
        | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("OAuth callback failed")
        | None => "OAuth callback failed"
        }
        response->endHttpResponse(message)
        codeResult.reject(error)
      }
    }
  })

  await Promise.make((resolve, reject) => {
    server->httpServerOnceError("error", reject)->ignore
    server->httpServerListen(0, "127.0.0.1", () => resolve(()))->ignore
  })

  let port = switch server->httpServerAddress {
  | Some(address) => address->serverAddressPort
  | None => fail("Failed to allocate loopback callback port")
  }

  loopbackServerObj(
    ~redirectUri="http://127.0.0.1:" ++ port->Int.toString ++ "/callback",
    ~waitForCode=() => codeResult.promise,
    ~close=() =>
      Promise.make((resolve, reject) => {
        server
        ->httpServerClose(error => {
          switch error->Nullable.toOption {
          | Some(error) => reject(error)
          | None => resolve(())
          }
        })
        ->ignore
      }),
    (),
  )
}

let raiseHttpError = (~message, ~status, ~payload: option<errorPayload>) => {
  let error = makeJsError(message)
  error->setErrorStatus(status)
  error->setErrorPayload(payload)
  throw(error)
}

let readJson = async (response: WebFetch.response): 'payload => {
  if response->WebFetch.ok {
    await response->responseJsonAs
  } else {
    let contentType =
      response->WebFetch.headers->WebFetch.getHeader("content-type")->Belt.Option.getWithDefault("")

    if contentType->includesString("application/json") {
      let payload: errorPayload = await response->responseJsonAs
      let message = switch payload->errorPayloadError {
      | Some(error) => error
      | None =>
        switch payload->errorPayloadMessage {
        | Some(message) => message
        | None => "HTTP " ++ response->WebFetch.status->Int.toString
        }
      }
      raiseHttpError(~message, ~status=response->WebFetch.status, ~payload=Some(payload))
    } else {
      let body = await response->WebFetch.text
      raiseHttpError(
        ~message=if body == "" {
          "HTTP " ++ response->WebFetch.status->Int.toString
        } else {
          body
        },
        ~status=response->WebFetch.status,
        ~payload=None,
      )
    }
  }
}

let canRefreshFromBundle = bundle =>
  bundle->tokenRefreshToken != None && bundle->tokenClientId != None

let isAuthFailure = error =>
  switch error->JsExn.fromException {
  | Some(jsError) =>
    switch jsError->jsErrorStatus {
    | Some(401) | Some(403) => true
    | _ => false
    }
  | None => false
  }

let isInteractiveRecoveryError = error =>
  if isAuthFailure(error) {
    true
  } else {
    switch error->JsExn.fromException {
    | Some(jsError) =>
      switch jsError->jsErrorPayload {
      | Some(payload) =>
        switch payload->errorPayloadError {
        | Some("invalid_grant") | Some("invalid_client") => true
        | _ => false
        }
      | None => false
      }
    | None => false
    }
  }

let parseResourceMetadataUrl = header => {
  let marker = "resource_metadata=\""
  let start = header->indexOfFrom(marker, 0)
  if start < 0 {
    None
  } else {
    let valueStart = start + marker->String.length
    let valueEnd = header->indexOfFrom("\"", valueStart)
    if valueEnd < 0 {
      None
    } else {
      Some(header->sliceFromTo(valueStart, valueEnd))
    }
  }
}

let authorizationServerMetadataUrlFrom = authorizationServer => {
  let url = makeUrl(authorizationServer)
  setUrlPathname(url, "/.well-known/oauth-authorization-server")
  setUrlSearch(url, "")
  setUrlHash(url, "")
  url->urlToString
}

type resourceMetadata = {authorization_servers: option<array<string>>}

let discoverAuthorizationServer = async (~fetchImpl) => {
  let protectedResponse = await fetchImpl(
    publishBaseUrl ++ "/v1/me",
    getDiscoveryFetchInit(~method="GET", ~redirect="manual", ()),
  )
  let resourceMetadataUrl =
    protectedResponse
    ->WebFetch.headers
    ->WebFetch.getHeader("www-authenticate")
    ->Belt.Option.flatMap(parseResourceMetadataUrl)

  switch resourceMetadataUrl {
  | Some(resourceMetadataUrl) =>
    let resourceMetadata: resourceMetadata = await readJson(
      await fetchImpl(resourceMetadataUrl, emptyFetchInit()),
    )
    let authorizationServer = switch resourceMetadata.authorization_servers {
    | Some(servers) =>
      switch servers[0] {
      | Some(server) => server
      | None => fail("Cloudflare Access resource metadata did not include authorization_servers")
      }
    | None => fail("Cloudflare Access resource metadata did not include authorization_servers")
    }
    await readJson(
      await fetchImpl(authorizationServerMetadataUrlFrom(authorizationServer), emptyFetchInit()),
    )
  | None =>
    let metadataUrl = makeUrlWithBase("/.well-known/oauth-authorization-server", publishBaseUrl)
    await readJson(
      await fetchImpl(
        metadataUrl->urlToString,
        getDiscoveryFetchInit(~method="GET", ~redirect="manual", ()),
      ),
    )
  }
}

let formEncode = pairs =>
  pairs
  ->Array.map(((key, value)) => encodeURIComponent(key) ++ "=" ++ encodeURIComponent(value))
  ->Array.join("&")

let registerPublicClient = async (~metadata, ~redirectUri, ~fetchImpl) => {
  let body = stringify({
    "redirect_uris": [redirectUri],
    "token_endpoint_auth_method": "none",
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code"],
    "resource": oauthResource,
  })
  await readJson(
    await fetchImpl(
      metadata->metadataRegistrationEndpoint,
      postFetchInit(~method="POST", ~headers=jsonHeaders(), ~body, ()),
    ),
  )
}

let exchangeCodeForToken = async (
  ~metadata,
  ~clientId,
  ~redirectUri,
  ~code,
  ~codeVerifier,
  ~fetchImpl,
) => {
  let body = formEncode([
    ("grant_type", "authorization_code"),
    ("client_id", clientId),
    ("code", code),
    ("code_verifier", codeVerifier),
    ("redirect_uri", redirectUri),
    ("resource", oauthResource),
  ])
  await readJson(
    await fetchImpl(
      metadata->metadataTokenEndpoint,
      postFetchInit(~method="POST", ~headers=formHeaders(), ~body, ()),
    ),
  )
}

let refreshTokenBundle = async (~metadata, ~clientId, ~refreshToken, ~fetchImpl) => {
  let body = formEncode([
    ("grant_type", "refresh_token"),
    ("refresh_token", refreshToken),
    ("client_id", clientId),
    ("resource", oauthResource),
  ])
  await readJson(
    await fetchImpl(
      metadata->metadataTokenEndpoint,
      postFetchInit(~method="POST", ~headers=formHeaders(), ~body, ()),
    ),
  )
}

let buildTokenBundle = (~tokenResponse, ~metadata, ~clientId, ~now, ~previous) => {
  let refreshToken = switch tokenResponse->tokenResponseRefreshToken {
  | Some(refreshToken) => Some(refreshToken)
  | None =>
    switch previous {
    | Some(previous) => previous->tokenRefreshToken
    | None => None
    }
  }
  tokenBundleObj(
    ~accessToken=tokenResponse->tokenResponseAccessToken,
    ~refreshToken,
    ~expiresAt=now +. tokenResponse->tokenResponseExpiresIn *. 1000.0,
    ~tokenEndpoint=metadata->metadataTokenEndpoint,
    ~authorizationEndpoint=metadata->metadataAuthorizationEndpoint,
    ~registrationEndpoint=metadata->metadataRegistrationEndpoint,
    ~clientId,
    ~resource=oauthResource,
    ~publishBaseUrl,
    (),
  )
}

let normalizeIdentity = (identity: identityPayload): PublishAuthTypes.authIdentity => {
  githubLogin: identity->identityPayloadGithubLogin,
  displayName: identity->identityPayloadDisplayName,
  email: identity->identityPayloadEmail,
}

let fetchCurrentIdentity = async (~accessToken, ~fetchImpl) => {
  let response = await fetchImpl(
    publishBaseUrl ++ "/v1/me",
    getAuthFetchInit(~method="GET", ~headers=authHeaders(accessToken), ()),
  )
  let identity: identityPayload = await readJson(response)
  normalizeIdentity(identity)
}

let fetchCurrentSession = async (~accessToken, ~fetchImpl) => {
  let identity = await fetchCurrentIdentity(~accessToken, ~fetchImpl)
  {identity, accessToken}
}

let runPublishAuthSession = async (maybeOptions: option<options>) => {
  let deps = depsFromOptions(maybeOptions)
  let fetchImpl = deps->depFetch->Belt.Option.orElse(globalFetch)
  let fetchImpl = switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("OAuth helper requires a fetch implementation")
  }
  let now = deps->depNow->Belt.Option.getWithDefault(dateNow)
  let targetPlatform = deps->depPlatform->Belt.Option.getWithDefault(platform)
  let homeDir =
    deps
    ->depHomeDir
    ->Belt.Option.getWithDefault(
      if targetPlatform == "win32" {
        NodeProcess.envGet("APPDATA")->Belt.Option.getWithDefault(homedir())
      } else {
        homedir()
      },
    )
  let readCache = deps->depReadCache->Belt.Option.getWithDefault(defaultReadCache)
  let writeCache = deps->depWriteCache->Belt.Option.getWithDefault(defaultWriteCache)
  let openBrowser =
    deps->depOpenBrowser->Belt.Option.getWithDefault(url => defaultOpenBrowser(url, None))
  let createLoopbackServer =
    deps
    ->depCreateLoopbackServer
    ->Belt.Option.getWithDefault(defaultCreateLoopbackServer)
  let randomString = deps->depRandomString->Belt.Option.getWithDefault(defaultRandomString)
  let makeCodeVerifier = deps->depCodeVerifier->Belt.Option.getWithDefault(defaultCodeVerifier)
  let createCodeChallenge =
    deps
    ->depCodeChallengeFromVerifier
    ->Belt.Option.getWithDefault(codeChallengeFromVerifier)
  let hostname = makeUrl(publishBaseUrl)->urlHostname
  let cachePath = cacheFilePathFor(cacheInputObj(~platform=targetPlatform, ~homeDir, ~hostname, ()))
  let cachedBundle = await readCache(cachePath)
  let strategy = selectAuthStrategyFromOption(cachedBundle, now())
  let metadataCache: ref<option<metadata>> = ref(None)

  let loadMetadata = async () =>
    switch metadataCache.contents {
    | Some(metadata) => metadata
    | None =>
      let metadata = await discoverAuthorizationServer(~fetchImpl)
      metadataCache := Some(metadata)
      metadata
    }

  let runRefreshFlow = async bundle => {
    let metadata = await loadMetadata()
    let clientId = switch bundle->tokenClientId {
    | Some(clientId) => clientId
    | None => fail("Cached OAuth bundle is missing clientId")
    }
    let refreshToken = switch bundle->tokenRefreshToken {
    | Some(refreshToken) => refreshToken
    | None => fail("Cached OAuth bundle is missing refreshToken")
    }
    let refreshed: tokenResponse = await refreshTokenBundle(
      ~metadata,
      ~clientId,
      ~refreshToken,
      ~fetchImpl,
    )
    let nextBundle = buildTokenBundle(
      ~tokenResponse=refreshed,
      ~metadata,
      ~clientId,
      ~now=now(),
      ~previous=Some(bundle),
    )

    await writeCache(cachePath, nextBundle)
    await fetchCurrentSession(
      ~accessToken=nextBundle->tokenAccessToken->Belt.Option.getExn,
      ~fetchImpl,
    )
  }

  let runInteractiveFlow = async () => {
    let metadata = await loadMetadata()
    let expectedState = randomString()
    let codeVerifier = makeCodeVerifier()
    let codeChallenge = createCodeChallenge(codeVerifier)
    let loopback = await createLoopbackServer(loopbackInput(~expectedState, ()))

    try {
      let client: clientRegistration = await registerPublicClient(
        ~metadata,
        ~redirectUri=loopback->loopbackRedirectUri,
        ~fetchImpl,
      )
      let authorizationUrl = makeUrl(metadata->metadataAuthorizationEndpoint)
      let params = authorizationUrl->urlSearchParams
      params->searchParamsSet("client_id", client->clientId)
      params->searchParamsSet("redirect_uri", loopback->loopbackRedirectUri)
      params->searchParamsSet("response_type", "code")
      params->searchParamsSet("resource", oauthResource)
      params->searchParamsSet("code_challenge", codeChallenge)
      params->searchParamsSet("code_challenge_method", "S256")
      params->searchParamsSet("state", expectedState)

      await openBrowser(authorizationUrl->urlToString)
      let callback = await loopback->loopbackWaitForCode
      let tokenResponse: tokenResponse = await exchangeCodeForToken(
        ~metadata,
        ~clientId=client->clientId,
        ~redirectUri=loopback->loopbackRedirectUri,
        ~code=callback->callbackCode,
        ~codeVerifier,
        ~fetchImpl,
      )
      let nextBundle = buildTokenBundle(
        ~tokenResponse,
        ~metadata,
        ~clientId=client->clientId,
        ~now=now(),
        ~previous=None,
      )

      await writeCache(cachePath, nextBundle)
      let session = await fetchCurrentSession(
        ~accessToken=nextBundle->tokenAccessToken->Belt.Option.getExn,
        ~fetchImpl,
      )
      await loopback->loopbackClose
      session
    } catch {
    | error =>
      await loopback->loopbackClose
      rethrowCaught(error)
    }
  }

  switch strategy {
  | "reuse" =>
    let bundle = cachedBundle->Belt.Option.getExn
    let accessToken = bundle->tokenAccessToken->Belt.Option.getExn
    try {
      await fetchCurrentSession(~accessToken, ~fetchImpl)
    } catch {
    | error =>
      if !isAuthFailure(error) {
        rethrowCaught(error)
      }
      if canRefreshFromBundle(bundle) {
        try {
          await runRefreshFlow(bundle)
        } catch {
        | refreshError =>
          if !isInteractiveRecoveryError(refreshError) {
            rethrowCaught(refreshError)
          }
          await runInteractiveFlow()
        }
      } else {
        await runInteractiveFlow()
      }
    }
  | "refresh" =>
    switch cachedBundle {
    | Some(bundle) if canRefreshFromBundle(bundle) =>
      try {
        await runRefreshFlow(bundle)
      } catch {
      | refreshError =>
        if !isInteractiveRecoveryError(refreshError) {
          rethrowCaught(refreshError)
        }
        await runInteractiveFlow()
      }
    | _ => await runInteractiveFlow()
    }
  | _ => await runInteractiveFlow()
  }
}

let runPublishAuth = async maybeOptions => {
  let session = await runPublishAuthSession(maybeOptions)
  session.identity
}

let readProjectPackageJson = async projectCwd => {
  let packageJsonPath = NodePath.join2(projectCwd, "package.json")
  try {
    (await NodeFs.readFileUtf8(packageJsonPath, "utf8"))->parseJson
  } catch {
  | _ => emptyPackageJson()
  }
}

let promptWithDefault = async (readline, label, defaultValue) => {
  let suffix = switch defaultValue {
  | Some(value) if value != "" => " [" ++ value ++ "]"
  | _ => ""
  }
  let answer = (await readline->question(label ++ suffix ++ ": "))->trim
  let value = if answer != "" {
    answer
  } else {
    defaultValue->Belt.Option.getWithDefault("")
  }

  if value == "" {
    fail(label ++ " is required")
  }
  value
}

let questionWithDefault = async (~stdin, ~stdout, ~label, ~defaultValue=?, ~completer=?) => {
  let readline = switch completer {
  | Some(completer) =>
    createInterface(readlineOptionsWithCompleter(~input=stdin, ~output=stdout, ~completer, ()))
  | None => createInterface(readlineOptions(~input=stdin, ~output=stdout, ()))
  }
  let answer = await promptWithDefault(readline, label, defaultValue)
  readline->closeReadline
  answer
}

let selectPackageName = async (~packageNames, ~stdin, ~stdout) => {
  if packageNames->Array.length == 0 {
    await questionWithDefault(~stdin, ~stdout, ~label="Package name")
  } else {
    await search(
      searchConfig(
        ~message="Package name",
        ~pageSize=8,
        ~source=async (term, _) => {
          let input = term->Belt.Option.getWithDefault("")->trim
          let matches =
            packageNames
            ->Array.filter(packageName => input == "" || packageName->includesString(input))
            ->Array.map(packageName => searchChoice(~name=packageName, ~value=packageName, ()))

          if input != "" && !(packageNames->Array.some(packageName => packageName == input)) {
            Array.concat(
              matches,
              [searchChoice(~name="Use custom package \"" ++ input ++ "\"", ~value=input, ())],
            )
          } else {
            matches
          }
        },
        (),
      ),
      promptContext(~input=stdin, ~output=stdout, ()),
    )
  }
}

let confirmPublishWith = async (~stdin, ~stdout) => {
  let readline = createInterface(readlineOptions(~input=stdin, ~output=stdout, ()))
  let answer = (
    await readline->question("Publish this release and overwrite matching existing releases? [y/N]: ")
  )->trim->toLowerCase
  readline->closeReadline
  answer == "y" || answer == "yes"
}

let releaseDeleteLabel = (release: publishedRelease) =>
  release.packageName ++
  " " ++
  release.peerPackageRange ++
  " / ReScript " ++ release.rescriptRange ++ " (" ++ release.variantLabel ++ ")"

let defaultSelectDeleteRelease: selectDeleteReleaseImpl = async (releases, includeShowAll, stdin, stdout) => {
  if stdin->inputIsTty != Some(true) || stdout->outputIsTty != Some(true) {
    fail("delete requires an interactive terminal")
  }

  if releases->Array.length == 0 {
    None
  } else {
    let showAllValue = "__show_all__"
    let choices =
      releases
      ->Array.map(release => searchChoice(~name=releaseDeleteLabel(release), ~value=release.id, ()))
      ->(
        releaseChoices =>
          if includeShowAll {
            Array.concat(
              releaseChoices,
              [searchChoice(~name="Show all", ~value=showAllValue, ())],
            )
          } else {
            releaseChoices
          }
      )
    let selectedId = await search(
      searchConfig(
        ~message="Select a release to delete",
        ~pageSize=12,
        ~source=async (term, _) => {
          let input = term->Belt.Option.getWithDefault("")->trim->toLowerCase
          if input == "" {
            choices
          } else {
            choices->Array.filter(choice => choice->choiceName->toLowerCase->includesString(input))
          }
        },
        (),
      ),
      promptContext(~input=stdin, ~output=stdout, ()),
    )

    if selectedId == showAllValue {
      None
    } else {
      releases->Array.find(release => release.id == selectedId)
    }
  }
}

let defaultConfirmDeleteRelease: confirmDeleteReleaseImpl = async (release, stdin, stdout) => {
  let readline = createInterface(readlineOptions(~input=stdin, ~output=stdout, ()))
  let answer = (
    await readline->question(
      "Delete " ++ releaseDeleteLabel(release) ++ "? This cannot be undone. [y/N]: ",
    )
  )->trim->toLowerCase
  readline->closeReadline
  answer == "y" || answer == "yes"
}

let pathCompleter = projectCwd =>
  inputValue => {
    let input = inputValue->trim
    let inputDirectory = if input->endsWith(NodePath.sep) {
      input
    } else {
      NodePath.dirname(input)
    }
    let inputBase = if input->endsWith(NodePath.sep) {
      ""
    } else {
      NodePath.basename(input)
    }
    let displayDirectory = if inputDirectory == "." {
      ""
    } else {
      inputDirectory
    }
    let absoluteDirectory = NodePath.resolve2(
      projectCwd,
      if displayDirectory == "" {
        "."
      } else {
        displayDirectory
      },
    )

    try {
      let matches =
        readdirSync(absoluteDirectory, NodeFs.readdirWithFileTypes(~withFileTypes=true, ()))
        ->Array.filter(entry => !(NodeFs.direntName(entry)->startsWith(".")))
        ->Array.filter(entry => NodeFs.direntName(entry)->startsWith(inputBase))
        ->Array.map(entry => {
          let completedPath = if displayDirectory == "" {
            NodeFs.direntName(entry)
          } else {
            NodePath.join2(displayDirectory, NodeFs.direntName(entry))
          }
          try {
            if statSync(NodePath.resolve2(projectCwd, completedPath))->NodeFs.isDirectory {
              completedPath ++ NodePath.sep
            } else {
              completedPath
            }
          } catch {
          | _ => completedPath
          }
        })
      (
        if matches->Array.length > 0 {
          matches
        } else {
          []
        },
        inputValue,
      )
    } catch {
    | _ => ([], inputValue)
    }
  }

let collectBindingFilesFrom = async (~sourcePath, ~cwd) => {
  let absoluteSourcePath = NodePath.resolve2(cwd, sourcePath)
  let sourceStats = await NodeFs.stat(absoluteSourcePath)

  if sourceStats->NodeFs.isFile {
    if !PublishSource.isBindingFilePath(absoluteSourcePath) {
      fail("Binding file must end with .res or .resi")
    }
    [
      {
        relativePath: NodePath.basename(absoluteSourcePath),
        content: await NodeFs.readFileUtf8(absoluteSourcePath, "utf8"),
      },
    ]
  } else if !(sourceStats->NodeFs.isDirectory) {
    fail("Binding source must be a file or folder")
  } else {
    let files: array<fileEntry> = []
    let rec walk = async (~directoryPath, ~relativeDirectoryPath) => {
      let entries = await NodeFs.readdir(
        directoryPath,
        NodeFs.readdirWithFileTypes(~withFileTypes=true, ()),
      )

      for index in 0 to entries->Array.length - 1 {
        switch entries[index] {
        | Some(entry) if entry->NodeFs.direntIsDirectory =>
          if !PublishSource.shouldSkipDirectory(entry->NodeFs.direntName) {
            await walk(
              ~directoryPath=NodePath.join2(directoryPath, entry->NodeFs.direntName),
              ~relativeDirectoryPath=NodePath.join2(
                relativeDirectoryPath,
                entry->NodeFs.direntName,
              ),
            )
          }
        | Some(entry) if entry->NodeFs.direntIsFile =>
          let name = entry->NodeFs.direntName
          if !(name->startsWith(".")) && PublishSource.isBindingFilePath(name) {
            let relativePath = PublishSource.toPosixPath(
              NodePath.join2(relativeDirectoryPath, name),
            )
            files
            ->Array.push({
              relativePath,
              content: await NodeFs.readFileUtf8(NodePath.join2(directoryPath, name), "utf8"),
            })
            ->ignore
          }
        | _ => ()
        }
      }
    }

    await walk(~directoryPath=absoluteSourcePath, ~relativeDirectoryPath="")
    files->sortInPlaceWith((left, right) => left.relativePath->localeCompare(right.relativePath))

    if files->Array.length == 0 {
      fail("Binding folder did not contain any .res or .resi files")
    }
    files
  }
}

let promptForPublishInput: promptForPublishInputImpl = async (input: promptInput) => {
  let projectCwd = input->promptInputCwd
  let promptStdin = input->promptInputStdin
  let promptStdout = input->promptInputStdout

  if promptStdin->inputIsTty != Some(true) || promptStdout->outputIsTty != Some(true) {
    fail("binding publish requires an interactive terminal")
  }

  let packageJson = await readProjectPackageJson(projectCwd)
  let rescriptVersionDefault = PackageJson.dependencyVersionFrom(packageJson, "rescript")
  let packageName = await selectPackageName(
    ~packageNames=PackageJson.dependencyNamesFrom(packageJson),
    ~stdin=promptStdin,
    ~stdout=promptStdout,
  )
  let packageVersionDefault = PackageJson.dependencyVersionFrom(packageJson, packageName)
  let sourcePath = await questionWithDefault(
    ~stdin=promptStdin,
    ~stdout=promptStdout,
    ~label="Binding file or folder",
    ~completer=pathCompleter(projectCwd),
  )
  let peerPackageRange = (
    await questionWithDefault(
      ~stdin=promptStdin,
      ~stdout=promptStdout,
      ~label="Minimum package version",
      ~defaultValue=?packageVersionDefault,
    )
  )->Validation.normalizeMinimumRange
  let rescriptRange = (
    await questionWithDefault(
      ~stdin=promptStdin,
      ~stdout=promptStdout,
      ~label="Minimum ReScript version",
      ~defaultValue=?rescriptVersionDefault,
    )
  )->Validation.normalizeMinimumRange
  let files = await collectBindingFilesFrom(~sourcePath, ~cwd=projectCwd)
  let variantLabel = PublishSource.deriveVariantLabel(sourcePath)

  Console.log("")
  Console.log("Publish summary:")
  Console.log("  Package: " ++ packageName)
  Console.log("  Binding source: " ++ sourcePath)
  Console.log("  Variant: " ++ variantLabel)
  Console.log("  Files: " ++ files->Array.length->Int.toString)
  Console.log("  Package version: " ++ peerPackageRange)
  Console.log("  ReScript version: " ++ rescriptRange)
  Console.log("")

  if await confirmPublishWith(~stdin=promptStdin, ~stdout=promptStdout) {
    Some({
      packageName,
      variantLabel,
      peerPackageRange,
      rescriptRange,
      description: None,
      files,
    })
  } else {
    None
  }
}

let publishRelease = async (~input, ~accessToken, ~fetchImpl) =>
  await readJson(
    await fetchImpl(
      publishBaseUrl ++ "/v1/releases",
      postFetchInit(
        ~method="POST",
        ~headers=publishHeaders(accessToken),
        ~body=stringify(input),
        (),
      ),
    ),
  )

let listPublishedReleases = async (~accessToken, ~fetchImpl, ~all=false) => {
  let payload: publishedReleaseListPayload = await readJson(
    await fetchImpl(
      publishBaseUrl ++
      "/v1/releases" ++
      if all {
        "?all=true"
      } else {
        ""
      },
      getAuthFetchInit(~method="GET", ~headers=authHeaders(accessToken), ()),
    ),
  )
  payload.releases->Belt.Option.getWithDefault([])
}

let deletePublishedRelease = async (~releaseId, ~accessToken, ~fetchImpl) =>
  await readJson(
    await fetchImpl(
      publishBaseUrl ++ "/v1/releases/" ++ encodeURIComponent(releaseId),
      deleteFetchInit(~method="DELETE", ~headers=authHeaders(accessToken), ()),
    ),
  )

let runPublish = async maybeOptions => {
  let deps = depsFromOptions(maybeOptions)
  let fetchImpl = deps->depFetch->Belt.Option.orElse(globalFetch)
  let fetchImpl = switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("Publish helper requires a fetch implementation")
  }
  let projectCwd = deps->depCwd->Belt.Option.getWithDefault(cwd())
  let prompt = deps->depPromptForPublishInput->Belt.Option.getWithDefault(promptForPublishInput)
  let promptStdin = deps->depStdin->Belt.Option.getWithDefault(stdin)
  let promptStdout = deps->depStdout->Belt.Option.getWithDefault(stdout)
  let input = await prompt(promptInputObj(~cwd=projectCwd, ~stdin=promptStdin, ~stdout=promptStdout, ()))

  switch input {
  | None => Console.log("Publish cancelled.")
  | Some(input) =>
    let session = await runPublishAuthSession(maybeOptions)
    let result = await publishRelease(~input, ~accessToken=session.accessToken, ~fetchImpl)
    if result->publishResultDuplicate {
      Console.log("Release already exists: " ++ result->publishResultReleaseId)
    } else {
      Console.log("Published release: " ++ result->publishResultReleaseId)
    }
    Console.log(
      result->publishResultPackageName ++
      " (" ++
      result->publishResultFileCount->Int.toString ++
      " file" ++
      if result->publishResultFileCount == 1 {
        ""
      } else {
        "s"
      } ++ ")",
    )
  }
}

let runDelete = async maybeOptions => {
  let deps = depsFromOptions(maybeOptions)
  let fetchImpl = deps->depFetch->Belt.Option.orElse(globalFetch)
  let fetchImpl = switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("Delete helper requires a fetch implementation")
  }
  let promptStdin = deps->depStdin->Belt.Option.getWithDefault(stdin)
  let promptStdout = deps->depStdout->Belt.Option.getWithDefault(stdout)
  let selectDeleteRelease =
    deps->depSelectDeleteRelease->Belt.Option.getWithDefault(defaultSelectDeleteRelease)
  let confirmDeleteRelease =
    deps->depConfirmDeleteRelease->Belt.Option.getWithDefault(defaultConfirmDeleteRelease)
  let session = await runPublishAuthSession(maybeOptions)
  let recentReleases = await listPublishedReleases(
    ~accessToken=session.accessToken,
    ~fetchImpl,
    ~all=false,
  )

  if recentReleases->Array.length == 0 {
    Console.log("No published releases found.")
  } else {
    let selectedRecent = await selectDeleteRelease(recentReleases, true, promptStdin, promptStdout)
    let selected = switch selectedRecent {
    | Some(release) => Some(release)
    | None =>
      let allReleases = await listPublishedReleases(
        ~accessToken=session.accessToken,
        ~fetchImpl,
        ~all=true,
      )
      await selectDeleteRelease(allReleases, false, promptStdin, promptStdout)
    }

    switch selected {
    | None => Console.log("Delete cancelled.")
    | Some(release) =>
      if await confirmDeleteRelease(release, promptStdin, promptStdout) {
        let result: deleteReleaseResult = await deletePublishedRelease(
          ~releaseId=release.id,
          ~accessToken=session.accessToken,
          ~fetchImpl,
        )
        if result.deleted {
          Console.log("Deleted release: " ++ result.releaseId)
          Console.log(result.packageName ++ " " ++ result.peerPackageRange)
        } else {
          Console.log("Delete failed.")
        }
      } else {
        Console.log("Delete cancelled.")
      }
    }
  }
}
