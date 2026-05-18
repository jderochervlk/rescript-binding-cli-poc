let assertTrue = (condition, label) => {
  if !condition {
    throw(Failure("Assertion failed: " ++ label))
  }
}

@scope("JSON") @val external stringify: 'a => string = "stringify"
@scope("JSON") @val external parse: string => 'a = "parse"
@send external includes: (string, string) => bool = "includes"
@send external startsWith: (string, string) => bool = "startsWith"
@send external some: (array<'a>, 'a => bool) => bool = "some"
@send external push: (array<'a>, 'a) => int = "push"
@send external join: (array<string>, string) => string = "join"
@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external trim: string => string = "trim"
@send external toLowerCase: string => string = "toLowerCase"
@send external getArray: (array<'a>, int) => option<'a> = "at"
@val external encodeURIComponent: string => string = "encodeURIComponent"

let assertStringEquals = (actual, expected, label) => assertTrue(actual == expected, label)

let assertJsonEquals = (actual, expected, label) =>
  assertStringEquals(stringify(actual), stringify(expected), label)

let messageFromError = error =>
  switch error->JsExn.fromException {
  | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("")
  | None =>
    let _ = error
    %raw(`error?._1 ?? error?.message ?? String(error)`)
  }
