let run = async () => {
  await NodeFs.chmod(NodePath.join2(NodeProcess.cwd(), "bin/index.mjs"), 0o755)
}

let () = {
  run()
  ->Promise.catch(async error => {
    let message = switch error->JsExn.fromException {
    | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("Failed to update bin mode")
    | None => "Failed to update bin mode"
    }
    Console.error(message)
    NodeProcess.exit(1)
  })
  ->ignore
}
