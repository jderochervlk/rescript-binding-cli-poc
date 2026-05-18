open TestSupport

type cacheWrite = {
  cachePath: string,
  bundle: PublishOAuth.tokenBundle,
}
type url
type searchParams

@obj external cacheInput: (~platform: string, ~homeDir: string, ~hostname: string, unit) => PublishOAuth.cacheInput = ""
@obj external openOptions: (~platform: string=?, ~spawn: PublishOAuth.spawnImpl=?, ~log: PublishOAuth.logImpl=?, unit) => PublishOAuth.openOptions = ""
@obj external callbackInput: (~callbackUrl: PublishOAuth.url, ~expectedState: string, unit) => PublishOAuth.oauthCallbackInput = ""
@obj external loopbackInput: (~expectedState: string, unit) => PublishOAuth.loopbackInput = ""
@obj external options: (~deps: PublishOAuth.deps, unit) => PublishOAuth.options = ""
@obj
external deps: (
  ~now: PublishOAuth.nowImpl=?,
  ~platform: string=?,
  ~homeDir: string=?,
  ~readCache: PublishOAuth.readCacheImpl=?,
  ~writeCache: PublishOAuth.writeCacheImpl=?,
  ~fetch: PublishOAuth.fetchImpl=?,
  ~openBrowser: PublishOAuth.openBrowserImpl=?,
  ~createLoopbackServer: PublishOAuth.createLoopbackServerImpl=?,
  ~randomString: PublishOAuth.stringFactory=?,
  ~codeVerifier: PublishOAuth.stringFactory=?,
  ~codeChallengeFromVerifier: PublishOAuth.codeChallengeImpl=?,
  ~promptForPublishInput: PublishOAuth.promptForPublishInputImpl=?,
  ~selectDeleteRelease: PublishOAuth.selectDeleteReleaseImpl=?,
  ~confirmDeleteRelease: PublishOAuth.confirmDeleteReleaseImpl=?,
  unit,
) => PublishOAuth.deps = ""

@obj external tokenBundle: (
  ~accessToken: string=?,
  ~refreshToken: string=?,
  ~expiresAt: float=?,
  ~clientId: string=?,
  unit,
) => PublishOAuth.tokenBundle = ""

@obj external loopbackCallback: (~code: string, ~state: string, unit) => PublishOAuth.callback = ""
@get external loopbackExpectedState: PublishOAuth.loopbackInput => string = "expectedState"
@get external loopbackRedirectUri: PublishOAuth.loopbackServer => string = "redirectUri"
@send external loopbackWaitForCode: PublishOAuth.loopbackServer => promise<PublishOAuth.callback> = "waitForCode"
@send external loopbackClose: PublishOAuth.loopbackServer => promise<unit> = "close"
@get external initRedirect: PublishOAuth.fetchInit => option<string> = "redirect"
@get external initBody: PublishOAuth.fetchInit => string = "body"
@get external initHeaders: PublishOAuth.fetchInit => 'headers = "headers"
@get external authorization: 'headers => string = "Authorization"
@get external bundleAccessToken: PublishOAuth.tokenBundle => string = "accessToken"
@get external bundleRefreshToken: PublishOAuth.tokenBundle => string = "refreshToken"
@get external bodyPackageName: 'body => string = "packageName"
@get external bodyFiles: 'body => array<RegistryTypes.fileEntry> = "files"
@get external code: 'callback => string = "code"
@val external fetch: string => promise<WebFetch.response> = "fetch"
@new external makeOAuthUrl: string => PublishOAuth.url = "URL"
@new external makeUrl: string => url = "URL"
@get external searchParams: url => searchParams = "searchParams"
@send external searchParamGet: (searchParams, string) => option<string> = "get"

let authorizationServerMetadataUrl = "https://team.cloudflareaccess.com/.well-known/oauth-authorization-server"
let resourceMetadataUrl = "https://rescript-binding-registry.josh-401.workers.dev/.well-known/cloudflare-access-protected-resource/api/publish/v1/me"
let now = 1716000000000.0
let nullBundle: PublishOAuth.tokenBundle = %raw("null")
let nullPublishInput: RegistryTypes.publishInput = %raw("null")

let authorizationServerMetadata = {
  "authorization_endpoint": "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/authorization",
  "token_endpoint": "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/token",
  "registration_endpoint": "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/registration",
}

let resourceMetadata = {
  "resource": PublishOAuth.publishBaseUrl ++ "/v1/me",
  "protected": true,
  "team_domain": "team.cloudflareaccess.com",
  "authorization_servers": ["https://team.cloudflareaccess.com"],
}

let redirectResponse = (): WebFetch.response =>
  %raw(`new Response(null, {
    status: 302,
    headers: {
      "www-authenticate": "Cloudflare-Access resource_metadata=\"https://rescript-binding-registry.josh-401.workers.dev/.well-known/cloudflare-access-protected-resource/api/publish/v1/me\"",
    },
  })`)

let discoveryResponseFor = (url, init) => {
  if url == PublishOAuth.publishBaseUrl ++ "/v1/me" && init->initRedirect == Some("manual") {
    Some(redirectResponse())
  } else if url == resourceMetadataUrl {
    Some(jsonResponse(resourceMetadata))
  } else if url == authorizationServerMetadataUrl {
    Some(jsonResponse(authorizationServerMetadata))
  } else {
    None
  }
}

let errorResponse = (~status, body): WebFetch.response => jsonResponse(~status, body)

let textResponse = (~status, ~body): WebFetch.response => {
  let _ = (status, body)
  %raw(`new Response(body, { status })`)
}

let missingBrowserSpawn: PublishOAuth.spawnImpl = %raw(`() => {
  const handlers = {};
  const child = {
    once(event, handler) {
      handlers[event] = handler;
      return child;
    },
  };
  queueMicrotask(() => {
    const error = new Error("spawn xdg-open ENOENT");
    error.code = "ENOENT";
    handlers.error?.(error);
  });
  return child;
}`)

let makeLoopbackServer = (~redirectUri, ~code, ~state): PublishOAuth.loopbackServer => {
  let _ = (redirectUri, code, state)
  %raw(`({
    redirectUri,
    waitForCode: async () => ({ code, state }),
    close: async () => {},
  })`)
}

let expectUnexpected = (flowName, url) => throw(Failure("Unexpected URL in " ++ flowName ++ ": " ++ url))

let readCache = bundle => async _cachePath => bundle
let noWriteCache = message => async (_cachePath, _bundle) => throw(Failure(message))
let noBrowser = message => async _url => throw(Failure(message))
let noLoopback = message => async _input => throw(Failure(message))

let assertAuthIdentity = (actual: option<string>, expected, label) =>
  assertTrue(actual == Some(expected), label)

let writtenBundle = (write: option<cacheWrite>) => {
  let write = write->Belt.Option.getExn
  write.bundle
}

let captureConsoleLog = (callback: unit => promise<unit>): promise<array<string>> => {
  let _ = callback
  %raw(`(async () => {
    const originalLog = console.log;
    const lines = [];
    console.log = message => {
      lines.push(String(message));
    };
    try {
      await callback();
      return lines;
    } finally {
      console.log = originalLog;
    }
  })()`)
}

let run = async () => {
  assertStringEquals(
    PublishOAuth.cacheFilePathFor(cacheInput(
      ~platform="linux",
      ~homeDir="/home/josh",
      ~hostname="rescript-binding-registry.josh-401.workers.dev",
      (),
    )),
    "/home/josh/.local/state/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
    "linux cache path uses XDG state directory",
  )
  assertStringEquals(
    PublishOAuth.cacheFilePathFor(cacheInput(
      ~platform="darwin",
      ~homeDir="/Users/josh",
      ~hostname="rescript-binding-registry.josh-401.workers.dev",
      (),
    )),
    "/Users/josh/Library/Application Support/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
    "macOS cache path uses Application Support",
  )
  assertStringEquals(
    PublishOAuth.cacheFilePathFor(cacheInput(
      ~platform="win32",
      ~homeDir="C:/Users/josh/AppData/Roaming",
      ~hostname="rescript-binding-registry.josh-401.workers.dev",
      (),
    )),
    "C:/Users/josh/AppData/Roaming/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
    "windows cache path uses roaming app data",
  )
  assertStringEquals(
    PublishOAuth.cacheFilePathFor(cacheInput(
      ~platform="win32",
      ~homeDir="C:\\Users\\josh\\AppData\\Roaming",
      ~hostname="rescript-binding-registry.josh-401.workers.dev",
      (),
    )),
    "C:/Users/josh/AppData/Roaming/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
    "windows cache path normalizes backslash base paths",
  )

  assertTrue(
    PublishOAuth.isAccessTokenUsable(tokenBundle(~accessToken="token", ~expiresAt=now +. 120000.0, ()), now),
    "access token with more than one minute remaining is reusable",
  )
  assertTrue(
    !PublishOAuth.isAccessTokenUsable(tokenBundle(~accessToken="token", ~expiresAt=now +. 10000.0, ()), now),
    "nearly expired access token is not reusable",
  )
  assertStringEquals(
    PublishOAuth.selectAuthStrategy(tokenBundle(~accessToken="token", ~expiresAt=now +. 120000.0, ()), now),
    "reuse",
    "valid access token uses reuse path",
  )
  assertStringEquals(
    PublishOAuth.selectAuthStrategy(
      tokenBundle(~accessToken="token", ~expiresAt=now -. 1000.0, ~refreshToken="refresh", ()),
      now,
    ),
    "refresh",
    "expired access token with refresh token uses refresh path",
  )
  assertStringEquals(PublishOAuth.selectAuthStrategy(nullBundle, now), "interactive", "missing bundle uses interactive path")

  let missingBrowserLogs = []
  await PublishOAuth.defaultOpenBrowser(
    "https://example.com/auth",
    Some(openOptions(
      ~platform="linux",
      ~spawn=missingBrowserSpawn,
      ~log=message => missingBrowserLogs->push(message)->ignore,
      (),
    )),
  )
  assertTrue(
    missingBrowserLogs->some(message => message->includes("https://example.com/auth")),
    "missing browser opener prints the auth URL instead of failing",
  )

  try {
    PublishOAuth.readOAuthCallback(callbackInput(
      ~callbackUrl=makeOAuthUrl("http://127.0.0.1:43123/callback"),
      ~expectedState="expected-state",
      (),
    ))->ignore
  } catch {
  | error =>
    assertTrue(messageFromError(error)->includes("Callback query was empty"), "missing callback query reports that the query was empty")
  }

  try {
    PublishOAuth.readOAuthCallback(callbackInput(
      ~callbackUrl=makeOAuthUrl("http://127.0.0.1:43123/callback?error=access_denied&error_description=Denied"),
      ~expectedState="expected-state",
      (),
    ))->ignore
  } catch {
  | error =>
    assertTrue(messageFromError(error)->includes("OAuth callback error: access_denied: Denied"), "OAuth callback error query is surfaced")
  }

  let validCallback = PublishOAuth.readOAuthCallback(callbackInput(
    ~callbackUrl=makeOAuthUrl("http://127.0.0.1:43123/callback?code=auth-code&state=expected-state"),
    ~expectedState="expected-state",
    (),
  ))
  assertStringEquals(validCallback->code, "auth-code", "valid OAuth callback returns the authorization code")

  let realLoopback = await PublishOAuth.defaultCreateLoopbackServer(loopbackInput(
    ~expectedState="loopback-state",
    (),
  ))
  try {
    let _ = await fetch(realLoopback->loopbackRedirectUri ++ "?code=loopback-code&state=loopback-state")
    let loopbackCallback = await realLoopback->loopbackWaitForCode
    assertStringEquals(loopbackCallback->code, "loopback-code", "default loopback server resolves callback code")
    await realLoopback->loopbackClose
  } catch {
  | error =>
    await realLoopback->loopbackClose
    throw(error)
  }

  let reuseMeAuth = ref("")
  let reuseResult = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
    ~now=() => now,
    ~platform="linux",
    ~homeDir="/home/josh",
    ~readCache=readCache(tokenBundle(
      ~accessToken="cached-token",
      ~refreshToken="oauth:refresh-token",
      ~expiresAt=now +. 120000.0,
      ~clientId="registered-client",
      (),
    )),
    ~writeCache=noWriteCache("reuse flow should not persist cache"),
    ~fetch=async (url, init) => {
      if url == PublishOAuth.publishBaseUrl ++ "/v1/me" {
        reuseMeAuth := init->initHeaders->authorization
        jsonResponse({
          "githubLogin": "cached-dev",
          "email": "cached@example.com",
          "access": {"authenticated": true},
        })
      } else {
        expectUnexpected("reuse flow", url)
      }
    },
    ~openBrowser=noBrowser("reuse flow should not open a browser"),
    ~createLoopbackServer=noLoopback("reuse flow should not start loopback server"),
    (),
  ), ())))
  assertStringEquals(reuseMeAuth.contents, "Bearer cached-token", "reuse flow uses cached bearer token for /v1/me")
  assertAuthIdentity(reuseResult.githubLogin, "cached-dev", "reuse flow returns cached identity result")

  let refreshTokenBody = ref("")
  let refreshWrite = ref(None)
  let refreshMeAuth = ref("")
  let refreshResult = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
    ~now=() => now,
    ~platform="linux",
    ~homeDir="/home/josh",
    ~readCache=readCache(tokenBundle(
      ~accessToken="expired-token",
      ~refreshToken="oauth:refresh-token",
      ~expiresAt=now -. 1000.0,
      ~clientId="registered-client",
      (),
    )),
    ~writeCache=async (cachePath, bundle) => refreshWrite := Some({cachePath, bundle}),
    ~fetch=async (url, init) => {
      switch discoveryResponseFor(url, init) {
      | Some(response) => response
      | None if url == authorizationServerMetadata["token_endpoint"] =>
        refreshTokenBody := init->initBody
        jsonResponse({"access_token": "fresh-token", "refresh_token": "oauth:new-refresh-token", "expires_in": 300})
      | None if url == PublishOAuth.publishBaseUrl ++ "/v1/me" =>
        refreshMeAuth := init->initHeaders->authorization
        jsonResponse({"email": "dev@example.com", "access": {"authenticated": true}})
      | None => expectUnexpected("refresh flow", url)
      }
    },
    ~openBrowser=noBrowser("refresh flow should not open a browser"),
    ~createLoopbackServer=noLoopback("refresh flow should not start loopback server"),
    (),
  ), ())))

  assertTrue(refreshTokenBody.contents->includes("grant_type=refresh_token"), "refresh token request uses refresh_token grant")
  assertTrue(refreshTokenBody.contents->includes("client_id=registered-client"), "refresh token request includes client_id")
  assertStringEquals(refreshMeAuth.contents, "Bearer fresh-token", "refresh flow uses bearer token for /v1/me")
  assertAuthIdentity(refreshResult.email, "dev@example.com", "refresh flow returns authenticated identity")
  assertStringEquals(
    refreshWrite.contents->writtenBundle->bundleAccessToken,
    "fresh-token",
    "refresh flow persists updated access token",
  )

  let refreshFailureMessage = ref("")
  try {
    let _ = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
      ~now=() => now,
      ~platform="linux",
      ~homeDir="/home/josh",
      ~readCache=readCache(tokenBundle(
        ~accessToken="expired-token",
        ~refreshToken="oauth:refresh-token",
        ~expiresAt=now -. 1000.0,
        ~clientId="registered-client",
        (),
      )),
      ~writeCache=noWriteCache("refresh failure should not persist cache"),
      ~fetch=async (url, init) => {
        switch discoveryResponseFor(url, init) {
        | Some(response) => response
        | None if url == authorizationServerMetadata["token_endpoint"] =>
          errorResponse(~status=400, {"message": "Bad refresh request"})
        | None => expectUnexpected("refresh failure flow", url)
        }
      },
      ~openBrowser=noBrowser("non-auth refresh failure should not fall back to browser auth"),
      ~createLoopbackServer=noLoopback("non-auth refresh failure should not start loopback server"),
      (),
    ), ())))
    ()
  } catch {
  | error => refreshFailureMessage := messageFromError(error)
  }
  assertStringEquals(
    refreshFailureMessage.contents,
    "Bad refresh request",
    "generic bad refresh requests are surfaced instead of falling back to interactive auth",
  )

  let invalidGrantOpenedUrl = ref("")
  let invalidGrantTokenBodies = []
  let invalidGrantWrite = ref(None)
  let invalidGrantResult = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
    ~now=() => now,
    ~platform="linux",
    ~homeDir="/home/josh",
    ~readCache=readCache(tokenBundle(
      ~accessToken="expired-token",
      ~refreshToken="oauth:refresh-token",
      ~expiresAt=now -. 1000.0,
      ~clientId="registered-client",
      (),
    )),
    ~writeCache=async (cachePath, bundle) => invalidGrantWrite := Some({cachePath, bundle}),
    ~randomString=() => "invalid-grant-state",
    ~codeVerifier=() => "invalid-grant-verifier",
    ~codeChallengeFromVerifier=_ => "invalid-grant-challenge",
    ~fetch=async (url, init) => {
      switch discoveryResponseFor(url, init) {
      | Some(response) => response
      | None if url == authorizationServerMetadata["registration_endpoint"] =>
        jsonResponse({"client_id": "interactive-after-invalid-grant-client", "redirect_uris": ["http://127.0.0.1:43125/callback"]})
      | None if url == authorizationServerMetadata["token_endpoint"] =>
        invalidGrantTokenBodies->push(init->initBody)->ignore
        if invalidGrantTokenBodies->Array.length == 1 {
          errorResponse(~status=400, {"error": "invalid_grant"})
        } else {
          jsonResponse({
            "access_token": "interactive-after-invalid-grant",
            "refresh_token": "oauth:interactive-after-invalid-grant",
            "expires_in": 300,
          })
        }
      | None if url == PublishOAuth.publishBaseUrl ++ "/v1/me" =>
        jsonResponse({"displayName": "Invalid Grant Recovery Dev", "email": "invalid-grant@example.com", "access": {"authenticated": true}})
      | None => expectUnexpected("invalid-grant recovery flow", url)
      }
    },
    ~createLoopbackServer=async input => {
      assertStringEquals(input->loopbackExpectedState, "invalid-grant-state", "invalid grant recovery uses expected state")
      makeLoopbackServer(
        ~redirectUri="http://127.0.0.1:43125/callback",
        ~code="invalid-grant-auth-code",
        ~state="invalid-grant-state",
      )
    },
    ~openBrowser=async url => invalidGrantOpenedUrl := url,
    (),
  ), ())))
  assertTrue(invalidGrantTokenBodies[0]->Belt.Option.getExn->includes("grant_type=refresh_token"), "invalid_grant first fails on refresh token exchange")
  assertTrue(invalidGrantTokenBodies[1]->Belt.Option.getExn->includes("grant_type=authorization_code"), "invalid_grant falls back to interactive code exchange")
  assertTrue(invalidGrantOpenedUrl.contents != "", "invalid_grant falls back to browser auth")
  assertStringEquals(
    invalidGrantWrite.contents->writtenBundle->bundleRefreshToken,
    "oauth:interactive-after-invalid-grant",
    "invalid_grant fallback persists the interactive refresh token",
  )
  assertAuthIdentity(invalidGrantResult.displayName, "Invalid Grant Recovery Dev", "invalid_grant fallback returns the interactive identity")

  let revokedTokenBody = ref("")
  let revokedWrite = ref(None)
  let revokedMeAuth = []
  let revokedResult = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
    ~now=() => now,
    ~platform="linux",
    ~homeDir="/home/josh",
    ~readCache=readCache(tokenBundle(
      ~accessToken="cached-token",
      ~refreshToken="oauth:refresh-token",
      ~expiresAt=now +. 120000.0,
      ~clientId="registered-client",
      (),
    )),
    ~writeCache=async (cachePath, bundle) => revokedWrite := Some({cachePath, bundle}),
    ~fetch=async (url, init) => {
      switch discoveryResponseFor(url, init) {
      | Some(response) => response
      | None if url == authorizationServerMetadata["token_endpoint"] =>
        revokedTokenBody := init->initBody
        jsonResponse({"access_token": "recovered-token", "refresh_token": "oauth:recovered-refresh", "expires_in": 300})
      | None if url == PublishOAuth.publishBaseUrl ++ "/v1/me" =>
        revokedMeAuth->push(init->initHeaders->authorization)->ignore
        if revokedMeAuth->Array.length == 1 {
          textResponse(~status=401, ~body="Unauthorized")
        } else {
          jsonResponse({"displayName": "Recovered Dev", "email": "recovered@example.com", "access": {"authenticated": true}})
        }
      | None => expectUnexpected("revoked-token flow", url)
      }
    },
    ~openBrowser=noBrowser("revoked-token recovery should not open a browser"),
    ~createLoopbackServer=noLoopback("revoked-token recovery should not start loopback server"),
    (),
  ), ())))
  assertStringEquals(revokedMeAuth[0]->Belt.Option.getExn, "Bearer cached-token", "revoked flow first tries the cached access token")
  assertTrue(revokedTokenBody.contents->includes("grant_type=refresh_token"), "revoked flow falls back to refresh")
  assertStringEquals(revokedMeAuth[1]->Belt.Option.getExn, "Bearer recovered-token", "revoked flow retries /v1/me with refreshed token")
  assertStringEquals(revokedWrite.contents->writtenBundle->bundleRefreshToken, "oauth:recovered-refresh", "revoked flow persists the recovered refresh token")
  assertAuthIdentity(revokedResult.displayName, "Recovered Dev", "revoked flow returns the recovered identity")

  let openedRecoveryUrl = ref("")
  let recoveryWrite = ref(None)
  let recoveryTokenBody = ref("")
  let recoveryResult = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
    ~now=() => now,
    ~platform="linux",
    ~homeDir="/home/josh",
    ~readCache=readCache(tokenBundle(
      ~accessToken="expired-token",
      ~refreshToken="oauth:refresh-token",
      ~expiresAt=now -. 1000.0,
      (),
    )),
    ~writeCache=async (cachePath, bundle) => recoveryWrite := Some({cachePath, bundle}),
    ~randomString=() => "fixed-recovery-state",
    ~codeVerifier=() => "fixed-recovery-verifier",
    ~codeChallengeFromVerifier=_ => "fixed-recovery-challenge",
    ~fetch=async (url, init) => {
      switch discoveryResponseFor(url, init) {
      | Some(response) => response
      | None if url == authorizationServerMetadata["registration_endpoint"] =>
        jsonResponse({"client_id": "interactive-client", "redirect_uris": ["http://127.0.0.1:43124/callback"]})
      | None if url == authorizationServerMetadata["token_endpoint"] =>
        recoveryTokenBody := init->initBody
        jsonResponse({"access_token": "interactive-after-incomplete", "refresh_token": "oauth:interactive-recovery", "expires_in": 300})
      | None if url == PublishOAuth.publishBaseUrl ++ "/v1/me" =>
        jsonResponse({"displayName": "Recovered Interactive Dev", "email": "recovery@example.com", "access": {"authenticated": true}})
      | None => expectUnexpected("incomplete-refresh recovery flow", url)
      }
    },
    ~createLoopbackServer=async input => {
      assertStringEquals(input->loopbackExpectedState, "fixed-recovery-state", "recovery loopback server receives expected OAuth state")
      makeLoopbackServer(
        ~redirectUri="http://127.0.0.1:43124/callback",
        ~code="recovery-auth-code",
        ~state="fixed-recovery-state",
      )
    },
    ~openBrowser=async url => openedRecoveryUrl := url,
    (),
  ), ())))
  assertTrue(recoveryTokenBody.contents->includes("grant_type=authorization_code"), "missing clientId falls back to interactive code exchange")
  assertTrue(openedRecoveryUrl.contents != "", "missing clientId falls back to browser auth")
  assertStringEquals(recoveryWrite.contents->writtenBundle->bundleRefreshToken, "oauth:interactive-recovery", "interactive recovery persists the refresh token")
  assertAuthIdentity(recoveryResult.displayName, "Recovered Interactive Dev", "missing clientId falls back to the interactive identity flow")

  let openedUrl = ref("")
  let savedInteractiveBundle = ref(None)
  let interactiveMeAuth = ref("")
  let interactiveResult = await PublishOAuth.runPublishAuth(Some(options(~deps=deps(
    ~now=() => now,
    ~platform="linux",
    ~homeDir="/home/josh",
    ~readCache=readCache(nullBundle),
    ~writeCache=async (cachePath, bundle) => savedInteractiveBundle := Some({cachePath, bundle}),
    ~randomString=() => "fixed-state-token",
    ~codeVerifier=() => "fixed-code-verifier",
    ~codeChallengeFromVerifier=_ => "fixed-code-challenge",
    ~fetch=async (url, init) => {
      switch discoveryResponseFor(url, init) {
      | Some(response) => response
      | None if url == authorizationServerMetadata["registration_endpoint"] =>
        jsonResponse({"client_id": "dynamic-client", "redirect_uris": ["http://127.0.0.1:43123/callback"]})
      | None if url == authorizationServerMetadata["token_endpoint"] =>
        jsonResponse({"access_token": "interactive-token", "refresh_token": "oauth:interactive-refresh", "expires_in": 300})
      | None if url == PublishOAuth.publishBaseUrl ++ "/v1/me" =>
        interactiveMeAuth := init->initHeaders->authorization
        jsonResponse({"displayName": "Interactive Dev", "email": "interactive@example.com", "access": {"authenticated": true}})
      | None => expectUnexpected("interactive flow", url)
      }
    },
    ~createLoopbackServer=async input => {
      assertStringEquals(input->loopbackExpectedState, "fixed-state-token", "loopback server receives expected OAuth state")
      makeLoopbackServer(
        ~redirectUri="http://127.0.0.1:43123/callback",
        ~code="auth-code",
        ~state="fixed-state-token",
      )
    },
    ~openBrowser=async url => openedUrl := url,
    (),
  ), ())))
  let interactiveAuthorizationUrl = makeUrl(openedUrl.contents)
  assertTrue(interactiveAuthorizationUrl->searchParams->searchParamGet("client_id") == Some("dynamic-client"), "interactive flow opens browser with registered client_id")
  assertTrue(interactiveAuthorizationUrl->searchParams->searchParamGet("code_challenge") == Some("fixed-code-challenge"), "interactive flow uses PKCE challenge")
  assertTrue(interactiveAuthorizationUrl->searchParams->searchParamGet("resource") == Some(PublishOAuth.publishBaseUrl ++ "/v1/me"), "interactive flow sends resource indicator")
  assertTrue(interactiveAuthorizationUrl->searchParams->searchParamGet("code_challenge_method") == Some("S256"), "interactive flow sets the PKCE challenge method")
  assertTrue(interactiveAuthorizationUrl->searchParams->searchParamGet("state") == Some("fixed-state-token"), "interactive flow sets the OAuth state")
  assertStringEquals(interactiveMeAuth.contents, "Bearer interactive-token", "interactive flow uses bearer token for /v1/me")
  assertAuthIdentity(interactiveResult.displayName, "Interactive Dev", "interactive flow returns authenticated identity")
  assertStringEquals(savedInteractiveBundle.contents->writtenBundle->bundleRefreshToken, "oauth:interactive-refresh", "interactive flow persists refresh token")

  let publishCancelLogs = await captureConsoleLog(async () => {
    await PublishOAuth.runPublish(Some(options(~deps=deps(
      ~fetch=async (_url, _init) => throw(Failure("cancelled publish should not call fetch")),
      ~promptForPublishInput=async _ => nullPublishInput,
      (),
    ), ())))
  })
  assertTrue(publishCancelLogs->some(message => message == "Publish cancelled."), "publish cancellation returns before authentication")

  let publishPostAuth = ref("")
  let publishPostBody = ref(None)
  let publishLogs = await captureConsoleLog(async () => {
    let promptInput: RegistryTypes.publishInput = {
      packageName: "@inquirer/prompts",
      variantLabel: "isEven",
      peerPackageRange: "^8.4.2",
      rescriptRange: "^12.0.0",
      description: None,
      files: [{relativePath: "isEven.res", content: "let x = 1\n"}],
    }
    await PublishOAuth.runPublish(Some(options(~deps=deps(
      ~now=() => now,
      ~platform="linux",
      ~homeDir="/home/josh",
      ~readCache=readCache(tokenBundle(
        ~accessToken="publish-token",
        ~refreshToken="oauth:publish-refresh",
        ~expiresAt=now +. 120000.0,
        ~clientId="publish-client",
        (),
      )),
      ~writeCache=noWriteCache("publish with reusable token should not persist cache"),
      ~fetch=async (url, init) => {
        if url == PublishOAuth.publishBaseUrl ++ "/v1/me" {
          jsonResponse({"displayName": "Publish Dev", "email": "publish@example.com", "access": {"authenticated": true}})
        } else if url == PublishOAuth.publishBaseUrl ++ "/v1/releases" {
          publishPostAuth := init->initHeaders->authorization
          publishPostBody := Some(TestSupport.parse(init->initBody))
          jsonResponse(
            ~status=201,
            {
              "releaseId": "published-release",
              "packageName": "@inquirer/prompts",
              "variantLabel": "isEven",
              "fileCount": 1,
              "duplicate": false,
            },
          )
        } else {
          expectUnexpected("publish flow", url)
        }
      },
      ~openBrowser=noBrowser("publish with reusable token should not open browser"),
      ~createLoopbackServer=noLoopback("publish with reusable token should not create loopback server"),
      ~promptForPublishInput=async _ => promptInput,
      (),
    ), ())))
  })

  let publishPostBody = publishPostBody.contents->Belt.Option.getExn
  let publishedFiles = publishPostBody->bodyFiles
  let publishedFile: RegistryTypes.fileEntry = publishedFiles[0]->Belt.Option.getExn
  assertStringEquals(publishPostAuth.contents, "Bearer publish-token", "publish sends the cached bearer token")
  assertStringEquals(publishPostBody->bodyPackageName, "@inquirer/prompts", "publish posts the prompted package name")
  assertStringEquals(
    publishedFile.relativePath,
    "isEven.res",
    "publish posts prompted file entries",
  )
  assertTrue(publishLogs->some(message => message == "Published release: published-release"), "publish prints the release id")
  assertTrue(publishLogs->some(message => message == "@inquirer/prompts (1 file)"), "publish prints a package-only success summary")
  assertTrue(
    !(publishLogs->some(message => message->includes("@inquirer/prompts/isEven"))),
    "publish success summary does not include variant or source filename",
  )

  let deleteRelease: PublishOAuth.publishedRelease = {
    id: "delete-release",
    packageName: "is-even",
    variantLabel: "Default",
    peerPackageRange: "^1.0.0",
    rescriptRange: "^12.0.0",
    createdAt: "2026-05-03T12:00:00.000Z",
  }
  let deletePostAuth = ref("")
  let selectedWithShowAll = ref(false)
  let confirmDeleteCalled = ref(false)
  let deleteLogs = await captureConsoleLog(async () => {
    await PublishOAuth.runDelete(Some(options(~deps=deps(
      ~now=() => now,
      ~platform="linux",
      ~homeDir="/home/josh",
      ~readCache=readCache(tokenBundle(
        ~accessToken="delete-token",
        ~refreshToken="oauth:delete-refresh",
        ~expiresAt=now +. 120000.0,
        ~clientId="delete-client",
        (),
      )),
      ~writeCache=noWriteCache("delete with reusable token should not persist cache"),
      ~fetch=async (url, init) => {
        if url == PublishOAuth.publishBaseUrl ++ "/v1/me" {
          jsonResponse({"displayName": "Delete Dev", "email": "delete@example.com", "access": {"authenticated": true}})
        } else if url == PublishOAuth.publishBaseUrl ++ "/v1/releases" {
          deletePostAuth := init->initHeaders->authorization
          jsonResponse({"releases": [deleteRelease]})
        } else if url == PublishOAuth.publishBaseUrl ++ "/v1/releases/delete-release" {
          deletePostAuth := init->initHeaders->authorization
          jsonResponse({
            "releaseId": "delete-release",
            "packageName": "is-even",
            "peerPackageRange": "^1.0.0",
            "rescriptRange": "^12.0.0",
            "deleted": true,
          })
        } else {
          expectUnexpected("delete flow", url)
        }
      },
      ~openBrowser=noBrowser("delete with reusable token should not open browser"),
      ~createLoopbackServer=noLoopback("delete with reusable token should not create loopback server"),
      ~selectDeleteRelease=async (releases, includeShowAll, _stdin, _stdout) => {
        selectedWithShowAll := includeShowAll
        releases[0]
      },
      ~confirmDeleteRelease=async (release, _stdin, _stdout) => {
        confirmDeleteCalled := release.id == "delete-release"
        true
      },
      (),
    ), ())))
  })

  assertStringEquals(deletePostAuth.contents, "Bearer delete-token", "delete sends the cached bearer token")
  assertTrue(selectedWithShowAll.contents, "delete initially offers the show-all option")
  assertTrue(confirmDeleteCalled.contents, "delete confirms the selected release")
  assertTrue(deleteLogs->some(message => message == "Deleted release: delete-release"), "delete prints deleted release id")

  let showAllFetchCalled = ref(false)
  let showAllSelectCount = ref(0)
  let showAllLogs = await captureConsoleLog(async () => {
    await PublishOAuth.runDelete(Some(options(~deps=deps(
      ~now=() => now,
      ~platform="linux",
      ~homeDir="/home/josh",
      ~readCache=readCache(tokenBundle(
        ~accessToken="show-all-token",
        ~refreshToken="oauth:show-all-refresh",
        ~expiresAt=now +. 120000.0,
        ~clientId="show-all-client",
        (),
      )),
      ~writeCache=noWriteCache("show-all delete with reusable token should not persist cache"),
      ~fetch=async (url, _init) => {
        if url == PublishOAuth.publishBaseUrl ++ "/v1/me" {
          jsonResponse({"displayName": "Delete Dev", "email": "delete@example.com", "access": {"authenticated": true}})
        } else if url == PublishOAuth.publishBaseUrl ++ "/v1/releases" {
          jsonResponse({"releases": [deleteRelease]})
        } else if url == PublishOAuth.publishBaseUrl ++ "/v1/releases?all=true" {
          showAllFetchCalled := true
          jsonResponse({"releases": [deleteRelease]})
        } else if url == PublishOAuth.publishBaseUrl ++ "/v1/releases/delete-release" {
          jsonResponse({
            "releaseId": "delete-release",
            "packageName": "is-even",
            "peerPackageRange": "^1.0.0",
            "rescriptRange": "^12.0.0",
            "deleted": true,
          })
        } else {
          expectUnexpected("delete show-all flow", url)
        }
      },
      ~openBrowser=noBrowser("show-all delete with reusable token should not open browser"),
      ~createLoopbackServer=noLoopback("show-all delete with reusable token should not create loopback server"),
      ~selectDeleteRelease=async (releases, _includeShowAll, _stdin, _stdout) => {
        showAllSelectCount := showAllSelectCount.contents + 1
        if showAllSelectCount.contents == 1 {
          None
        } else {
          releases[0]
        }
      },
      ~confirmDeleteRelease=async (_release, _stdin, _stdout) => true,
      (),
    ), ())))
  })
  assertTrue(showAllFetchCalled.contents, "delete fetches all releases after selecting show all")
  assertTrue(showAllLogs->some(message => message == "Deleted release: delete-release"), "delete completes after show all selection")

  Console.log("PublishOAuth_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
