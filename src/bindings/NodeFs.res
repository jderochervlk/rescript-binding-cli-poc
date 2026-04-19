@module("node:fs/promises") external readFileUtf8: (string, string) => promise<string> = "readFile"
@module("node:fs/promises")
external writeFileUtf8: (string, string, string) => promise<unit> = "writeFile"
@module("node:fs/promises")
external mkdirRecursive: (string, {"recursive": bool}) => promise<unit> = "mkdir"
