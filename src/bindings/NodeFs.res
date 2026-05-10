@module("node:fs/promises") external readFileUtf8: (string, string) => promise<string> = "readFile"
@module("node:fs/promises")
external writeFileUtf8: (string, string, string) => promise<unit> = "writeFile"
@module("node:fs/promises")
external mkdirRecursive: (string, {"recursive": bool}) => promise<unit> = "mkdir"
@module("node:fs/promises") external chmod: (string, int) => promise<unit> = "chmod"
@module("node:fs/promises") external mkdtemp: string => promise<string> = "mkdtemp"
@module("node:fs/promises") external rm: (string, {"recursive": bool, "force": bool}) => promise<unit> = "rm"

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

@module("node:fs") external existsSync: string => bool = "existsSync"
@module("node:fs") external readFileSyncUtf8: (string, string) => string = "readFileSync"
@module("node:fs") external statSync: string => stats = "statSync"
@get external mode: stats => int = "mode"
