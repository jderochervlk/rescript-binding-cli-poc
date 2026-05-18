/** Hard-coded registry endpoints for the proof of concept.

    Keeping these in ReScript makes the read API, publish API, and OAuth resource
    share one source of truth. */

let registryApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api"
let publishBaseUrl = registryApiBaseUrl ++ "/publish"
let oauthResource = publishBaseUrl ++ "/v1/me"
