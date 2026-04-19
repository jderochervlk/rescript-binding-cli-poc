@module("node:process") external argv: array<string> = "argv"
@module("node:process") external cwd: unit => string = "cwd"
@module("node:process") external envGet: string => option<string> = "env"
