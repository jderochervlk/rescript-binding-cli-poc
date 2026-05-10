let assertTrue = (condition, label) => {
  if !condition {
    throw(Failure("Assertion failed: " ++ label))
  }
}

@send external includes: (string, string) => bool = "includes"

let messageFromError = error =>
  switch error->JsExn.fromException {
  | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("")
  | None =>
    let _ = error
    %raw(`error?._1 ?? error?.message ?? String(error)`)
  }
