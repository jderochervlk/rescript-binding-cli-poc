let () = {
  switch Cli.parse(NodeProcess.argv) {
  | Some(("add", packageName, folder)) => {
      switch folder {
      | Some(path) => Console.log("Install package " ++ packageName ++ " to " ++ path)
      | None => Console.log("Install package " ++ packageName)
      }
    }
  | Some(("publish", _, _)) => Console.log("Publish flow scaffold is wired in ReScript")
  | _ => Cli.usage()
  }
}
