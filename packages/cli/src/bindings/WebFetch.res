type headers
type response
type requestInit
type jsonValue

@val external fetch: (string, requestInit) => promise<response> = "fetch"
@get external ok: response => bool = "ok"
@get external status: response => int = "status"
@send external json: response => promise<jsonValue> = "json"
@send external text: response => promise<string> = "text"
@get external headers: response => headers = "headers"
@send external getHeader: (headers, string) => option<string> = "get"
