/** Turns npm package names into ReScript module-safe PascalCase names. */

@send external charCodeAt: (string, int) => int = "charCodeAt"
@send external slice: (string, int, int) => string = "slice"
@send external toUpperCase: string => string = "toUpperCase"
@send external push: (array<'a>, 'a) => int = "push"
@send external join: (array<string>, string) => string = "join"

let isAsciiDigit = code => code >= 48 && code <= 57
let isAsciiLetter = code => (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
let isAsciiAlphaNumeric = code => isAsciiLetter(code) || isAsciiDigit(code)

let upperFirst = value => {
  if String.length(value) == 0 {
    value
  } else {
    slice(value, 0, 1)->toUpperCase ++ slice(value, 1, String.length(value))
  }
}

let startsWithUppercase = value => {
  String.length(value) > 0 && {
    let code = charCodeAt(value, 0)
    code >= 65 && code <= 90
  }
}

let splitPackageParts = packageName => {
  let parts: array<string> = []
  let current = ref("")

  for index in 0 to String.length(packageName) - 1 {
    let code = charCodeAt(packageName, index)
    if isAsciiAlphaNumeric(code) {
      current := current.contents ++ slice(packageName, index, index + 1)
    } else if current.contents != "" {
      push(parts, current.contents)->ignore
      current := ""
    }
  }

  if current.contents != "" {
    push(parts, current.contents)->ignore
  }

  parts
}

let toModuleName = packageName => {
  let name =
    packageName
    ->splitPackageParts
    ->Array.map(upperFirst)
    ->join("")

  if name == "" {
    "Binding"
  } else if startsWithUppercase(name) {
    name
  } else {
    "Binding" ++ name
  }
}
