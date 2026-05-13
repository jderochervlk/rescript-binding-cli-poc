open TestSupport

@obj external loopbackInput: (~expectedState: string, unit) => PublishOAuth.loopbackInput = ""
@get external loopbackRedirectUri: PublishOAuth.loopbackServer => string = "redirectUri"
@send
external loopbackWaitForCode: PublishOAuth.loopbackServer => promise<PublishOAuth.callback> =
  "waitForCode"
@send external loopbackClose: PublishOAuth.loopbackServer => promise<unit> = "close"
@get external code: PublishOAuth.callback => string = "code"
@obj external emptyRequestInit: unit => WebFetch.requestInit = ""

let run = async () => {
  let loopback = await PublishOAuth.defaultCreateLoopbackServer(
    loopbackInput(~expectedState="loopback-state", ()),
  )

  try {
    let callbackPromise = loopback->loopbackWaitForCode
    let response = await WebFetch.fetch(
      loopback->loopbackRedirectUri ++ "?code=loopback-code&state=loopback-state",
      emptyRequestInit(),
    )
    assertTrue(response->WebFetch.ok, "default loopback server accepts a valid OAuth callback")
    let callback = await callbackPromise
    assertStringEquals(
      callback->code,
      "loopback-code",
      "default loopback server resolves with callback code",
    )
    await loopback->loopbackClose
  } catch {
  | error =>
    await loopback->loopbackClose
    throw(error)
  }

  Console.log("PublishOAuthLoopback_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
