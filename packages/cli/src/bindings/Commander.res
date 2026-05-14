type program
type addOptions
type outputConfig
type writable

@module("commander") @new external make: unit => program = "Command"

@send external name: (program, string) => program = "name"
@send external description: (program, string) => program = "description"
@send external version: (program, string) => program = "version"
@send external showHelpAfterError: (program, string) => program = "showHelpAfterError"
@send external configureOutput: (program, outputConfig) => program = "configureOutput"
@send external exitOverride: program => program = "exitOverride"
@send external command: (program, string) => program = "command"
@send external argument: (program, string, string) => program = "argument"
@send external option: (program, string, string) => program = "option"
@send external parseAsync: (program, array<string>) => promise<unit> = "parseAsync"
@send external write: (writable, string) => bool = "write"

@send
external actionAdd: (program, (option<string>, addOptions) => promise<unit>) => program = "action"

@send external actionPublish: (program, unit => promise<unit>) => program = "action"
@send external actionSearch: (program, string => promise<unit>) => program = "action"
@send external actionGet: (program, (string, string) => promise<unit>) => program = "action"

@get external folder: addOptions => option<string> = "folder"

@obj
external outputConfig: (
  ~writeOut: string => bool,
  ~writeErr: string => bool,
  ~outputError: (string, string => bool) => unit,
  unit,
) => outputConfig = ""
