/** Chooses whether publish auth can reuse, refresh, or must open a browser. */

type strategy = Reuse | Refresh | Interactive

let expirySafetyWindowMs = 60_000.0

let isAccessTokenUsable = (~hasAccessToken: bool, ~expiresAt: option<float>, ~now: float) =>
  switch expiresAt {
  | Some(expiresAt) => hasAccessToken && expiresAt -. now > expirySafetyWindowMs
  | None => false
  }

let select = (~hasUsableAccessToken: bool, ~hasRefreshToken: bool) => {
  if hasUsableAccessToken {
    Reuse
  } else if hasRefreshToken {
    Refresh
  } else {
    Interactive
  }
}

let toString = strategy =>
  switch strategy {
  | Reuse => "reuse"
  | Refresh => "refresh"
  | Interactive => "interactive"
  }

let selectName = (~hasUsableAccessToken: bool, ~hasRefreshToken: bool) =>
  select(~hasUsableAccessToken, ~hasRefreshToken)->toString
