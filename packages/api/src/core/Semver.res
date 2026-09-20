type version = {
  major: int,
  minor: int,
  patch: int,
}

type parsedVersion = {
  version: version,
  componentCount: int,
}

type bound = {
  version: version,
  inclusive: bool,
}

type interval = {
  lower: option<bound>,
  upper: option<bound>,
}

type operator =
  | Exact
  | GreaterThan
  | GreaterThanOrEqual
  | LessThan
  | LessThanOrEqual
  | Caret
  | Tilde

let compareVersions = (left: version, right: version) => {
  if left.major != right.major {
    left.major - right.major
  } else if left.minor != right.minor {
    left.minor - right.minor
  } else {
    left.patch - right.patch
  }
}

let parseComponent = value =>
  switch value->Int.fromString {
  | Some(value) if value >= 0 => Some(value)
  | _ => None
  }

let parseVersion = value => {
  let parts = value->String.split(".")
  let componentCount = parts->Array.length
  if componentCount < 1 || componentCount > 3 {
    None
  } else {
    switch parts->Array.get(0)->Option.flatMap(parseComponent) {
    | None => None
    | Some(major) =>
      let minor = switch parts->Array.get(1) {
      | Some(value) => value->parseComponent
      | None => Some(0)
      }
      let patch = switch parts->Array.get(2) {
      | Some(value) => value->parseComponent
      | None => Some(0)
      }
      switch (minor, patch) {
      | (Some(minor), Some(patch)) => Some({
          version: {major, minor, patch},
          componentCount,
        })
      | _ => None
      }
    }
  }
}

let operatorAndVersion = token => {
  if token->String.startsWith(">=") {
    (GreaterThanOrEqual, token->String.slice(~start=2))
  } else if token->String.startsWith("<=") {
    (LessThanOrEqual, token->String.slice(~start=2))
  } else if token->String.startsWith(">") {
    (GreaterThan, token->String.slice(~start=1))
  } else if token->String.startsWith("<") {
    (LessThan, token->String.slice(~start=1))
  } else if token->String.startsWith("^") {
    (Caret, token->String.slice(~start=1))
  } else if token->String.startsWith("~") {
    (Tilde, token->String.slice(~start=1))
  } else if token->String.startsWith("=") {
    (Exact, token->String.slice(~start=1))
  } else {
    (Exact, token)
  }
}

let tighterLower = (current: option<bound>, candidate: bound): option<bound> =>
  switch current {
  | None => Some(candidate)
  | Some(current) =>
    let comparison = compareVersions(candidate.version, current.version)
    if comparison > 0 {
      Some(candidate)
    } else if comparison < 0 {
      Some(current)
    } else {
      Some({...current, inclusive: current.inclusive && candidate.inclusive})
    }
  }

let tighterUpper = (current: option<bound>, candidate: bound): option<bound> =>
  switch current {
  | None => Some(candidate)
  | Some(current) =>
    let comparison = compareVersions(candidate.version, current.version)
    if comparison < 0 {
      Some(candidate)
    } else if comparison > 0 {
      Some(current)
    } else {
      Some({...current, inclusive: current.inclusive && candidate.inclusive})
    }
  }

let withLower = (interval: interval, bound: bound) => {
  ...interval,
  lower: tighterLower(interval.lower, bound),
}
let withUpper = (interval: interval, bound: bound) => {
  ...interval,
  upper: tighterUpper(interval.upper, bound),
}

let caretUpperBound = version =>
  if version.major > 0 {
    {major: version.major + 1, minor: 0, patch: 0}
  } else if version.minor > 0 {
    {major: 0, minor: version.minor + 1, patch: 0}
  } else {
    {major: 0, minor: 0, patch: version.patch + 1}
  }

let tildeUpperBound = (version, componentCount) =>
  if componentCount == 1 {
    {major: version.major + 1, minor: 0, patch: 0}
  } else {
    {major: version.major, minor: version.minor + 1, patch: 0}
  }

let applyToken = (interval, token) => {
  let (operator, versionText) = operatorAndVersion(token)
  switch versionText->parseVersion {
  | None => None
  | Some(parsed) =>
    let inclusiveBound = {version: parsed.version, inclusive: true}
    let exclusiveBound = {version: parsed.version, inclusive: false}
    Some(switch operator {
    | Exact => interval->withLower(inclusiveBound)->withUpper(inclusiveBound)
    | GreaterThan => interval->withLower(exclusiveBound)
    | GreaterThanOrEqual => interval->withLower(inclusiveBound)
    | LessThan => interval->withUpper(exclusiveBound)
    | LessThanOrEqual => interval->withUpper(inclusiveBound)
    | Caret =>
      interval
      ->withLower(inclusiveBound)
      ->withUpper({version: caretUpperBound(parsed.version), inclusive: false})
    | Tilde =>
      interval
      ->withLower(inclusiveBound)
      ->withUpper({
        version: tildeUpperBound(parsed.version, parsed.componentCount),
        inclusive: false,
      })
    })
  }
}

let isNonEmpty = interval =>
  switch (interval.lower, interval.upper) {
  | (Some(lower), Some(upper)) =>
    let comparison = compareVersions(lower.version, upper.version)
    comparison < 0 || (comparison == 0 && lower.inclusive && upper.inclusive)
  | _ => true
  }

let parseRange = value => {
  let tokens = value->String.trim->String.split(" ")->Array.filter(token => token != "")
  if tokens->Array.length == 0 {
    None
  } else {
    tokens->Array.reduce(Some({lower: None, upper: None}), (result, token) =>
      switch result {
      | Some(interval) => interval->applyToken(token)
      | None => None
      }
    )
  }
}

let intersect = (left, right) => {
  lower: switch right.lower {
  | Some(bound) => tighterLower(left.lower, bound)
  | None => left.lower
  },
  upper: switch right.upper {
  | Some(bound) => tighterUpper(left.upper, bound)
  | None => left.upper
  },
}

let rangesIntersect = (left, right) =>
  switch (left->parseRange, right->parseRange) {
  | (Some(left), Some(right)) => intersect(left, right)->isNonEmpty
  | _ => false
  }
