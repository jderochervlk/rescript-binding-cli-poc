@module("node:fs/promises") external readFileUtf8: (string, string) => promise<string> = "readFile"
@module("node:fs/promises")
external writeFileUtf8: (string, string, string) => promise<unit> = "writeFile"
@module("node:fs/promises")
external mkdirRecursive: (string, {"recursive": bool}) => promise<unit> = "mkdir"

type stats
type dirent
type readdirOptions

@module("node:fs/promises") external stat: string => promise<stats> = "stat"
@module("node:fs/promises") external readdir: (string, readdirOptions) => promise<array<dirent>> = "readdir"
@send external isFile: stats => bool = "isFile"
@send external isDirectory: stats => bool = "isDirectory"
@send external direntIsFile: dirent => bool = "isFile"
@send external direntIsDirectory: dirent => bool = "isDirectory"
@get external direntName: dirent => string = "name"
@obj external readdirWithFileTypes: (~withFileTypes: bool, unit) => readdirOptions = ""
