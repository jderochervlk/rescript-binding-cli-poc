type request
type response
type responseInit
type textResponse

@new external makeRequest: string => Worker.request = "Request"
@get external responseStatus: Worker.response => int = "status"
@send external responseText: Worker.response => promise<string> = "text"

let emptyEnv: Worker.env = %raw(`({ REGISTRY_API_BASE: "https://registry.test/api" })`)
let ctx = %raw(`({})`)

let fakeFetcher = async _url => {
  let body = `{"entries":[]}`
  Worker.makeResponse(body, Worker.responseInit(
    ~status=200,
    ~headers=[["content-type", "application/json"]],
    (),
  ))
}

let run = async () => {
  let response = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/"), emptyEnv, ctx)
  TestSupport.assertTrue(response->responseStatus == 200, "homepage smoke returns success")
  let html = await response->responseText
  TestSupport.assertTrue(html->TestSupport.includes("<!DOCTYPE html>"), "homepage smoke renders a document")
  TestSupport.assertTrue(html->TestSupport.includes("picocss"), "homepage smoke includes Pico CDN")
  TestSupport.assertTrue(html->TestSupport.includes("ReScript Bindings"), "homepage smoke includes heading")

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
