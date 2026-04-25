@module("node:process") external argv: array<string> = "argv"
@module("node:process") external cwd: unit => string = "cwd"
@module("node:process") external env: dict<string> = "env"
let envGet = key => Dict.get(env, key)
@module("node:process") external exit: int => 'a = "exit"
