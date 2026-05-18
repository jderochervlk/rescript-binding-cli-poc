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
    switch error {
    | Failure(message) => message
    | _ => ""
    }
  }
