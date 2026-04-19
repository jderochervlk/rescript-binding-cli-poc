type headers
type response
type requestInit
type jsonValue

@val external fetch: (string, requestInit) => promise<response> = "fetch"
@send external ok: response => bool = "ok"
@send external status: response => int = "status"
@send external json: response => promise<jsonValue> = "json"
