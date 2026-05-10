/** Normalizes install paths so the final file is a ReScript module filename. */

exception InvalidFilename(string)

let errorMessage =
  "Install filename must be a valid ReScript module filename, like InquirerPrompts.res."

@send external charCodeAt: (string, int) => int = "charCodeAt"
@send external slice: (string, int, int) => string = "slice"
@send external trim: string => string = "trim"
@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external split: (string, string) => array<string> = "split"
@send external join: (array<string>, string) => string = "join"
@send external endsWith: (string, string) => bool = "endsWith"
@send external toUpperCase: string => string = "toUpperCase"
@send external sliceArray: (array<'a>, int, int) => array<'a> = "slice"

let isAsciiDigit = code => code >= 48 && code <= 57
let isAsciiLetter = code => (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
let isAsciiAlphaNumeric = code => isAsciiLetter(code) || isAsciiDigit(code)

let invalid = () => throw(InvalidFilename(errorMessage))

let extensionAndStem = filename => {
  if endsWith(filename, ".resi") {
    (slice(filename, 0, String.length(filename) - 5), ".resi")
  } else if endsWith(filename, ".res") {
    (slice(filename, 0, String.length(filename) - 4), ".res")
  } else {
    invalid()
  }
}

let validateStem = stem => {
  if String.length(stem) == 0 || !isAsciiLetter(charCodeAt(stem, 0)) {
    invalid()
  }

  for index in 0 to String.length(stem) - 1 {
    if !isAsciiAlphaNumeric(charCodeAt(stem, index)) {
      invalid()
    }
  }
}

let normalizeBasename = filename => {
  let (stem, extension) = extensionAndStem(filename)
  validateStem(stem)
  slice(stem, 0, 1)->toUpperCase ++ slice(stem, 1, String.length(stem)) ++ extension
}

let normalizePath = path => {
  let normalized = path->replaceAll("\\", "/")->trim
  if normalized == "" || normalized == "." {
    invalid()
  }

  let parts = normalized->split("/")->Array.filter(part => part != "")

  let count = parts->Array.length
  if count == 0 {
    invalid()
  }

  let filename =
    switch parts[count - 1] {
    | Some(filename) => normalizeBasename(filename)
    | None => invalid()
    }
  if count == 1 {
    filename
  } else {
    let directories = sliceArray(parts, 0, count - 1)->join("/")
    directories ++ "/" ++ filename
  }
}
