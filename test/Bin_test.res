type fileUrl
type runResult = {
  stdout: string,
  stderr: string,
  exitCode: option<int>,
}
type cliModule

@module("node:url") external pathToFileURL: string => fileUrl = "pathToFileURL"
@get external href: fileUrl => string = "href"
@get external packageBinPath: 'packageJson => string = "bin"
@get external runStdout: runResult => string = "stdout"
@get external runStderr: runResult => string = "stderr"
@get external runExitCode: runResult => option<int> = "exitCode"
@get external cliRunPublishAuthCheckWith: cliModule => (unit => promise<PublishAuthTypes.authIdentity>) => promise<unit> = "runPublishAuthCheckWith"

let importBinWithArgs = (args, tag, wrapperPath, wrapperHref): promise<runResult> => {
  let _ = (args, tag, wrapperPath, wrapperHref)
  %raw(`(async () => {
    const originalArgv = process.argv;
    const originalExitCode = process.exitCode;
    const originalStdoutWrite = process.stdout.write;
    const originalStderrWrite = process.stderr.write;
    let stdout = "";
    let stderr = "";

    process.argv = [process.execPath, wrapperPath, ...args];
    process.exitCode = undefined;
    process.stdout.write = chunk => {
      stdout += String(chunk);
      return true;
    };
    process.stderr.write = chunk => {
      stderr += String(chunk);
      return true;
    };

    try {
      const module = await import(wrapperHref + "?" + tag);
      await module.ready;
      await new Promise(resolve => setImmediate(resolve));
      return { stdout, stderr, exitCode: process.exitCode };
    } finally {
      process.argv = originalArgv;
      process.exitCode = originalExitCode;
      process.stdout.write = originalStdoutWrite;
      process.stderr.write = originalStderrWrite;
    }
  })()`)
}

let importModule = href => {
  let _ = href
  %raw(`import(href)`)
}

let captureConsoleLog = (callback: unit => promise<unit>): promise<array<string>> => {
  let _ = callback
  %raw(`(async () => {
    const originalLog = console.log;
    const loggedLines = [];

    console.log = (...args) => {
      loggedLines.push(args.join(" "));
    };

    try {
      await callback();
      return loggedLines;
    } finally {
      console.log = originalLog;
    }
  })()`)
}

let hasExecutableBit = mode => {
  let _ = mode
  %raw(`(mode & 0o111) !== 0`)
}

let run = async () => {
  let packageJsonPath = NodePath.join2(NodeProcess.cwd(), "package.json")
  let wrapperPath = NodePath.join2(NodeProcess.cwd(), "bin/index.mjs")
  let cliPath = NodePath.join2(NodeProcess.cwd(), "src/Cli.res.mjs")
  let wrapperHref = wrapperPath->pathToFileURL->href
  let cliHref = cliPath->pathToFileURL->href
  let packageJson = NodeFs.readFileSyncUtf8(packageJsonPath, "utf8")->TestSupport.parse

  TestSupport.assertStringEquals(
    packageJson->packageBinPath,
    "./bin/index.mjs",
    "package.json points the CLI bin at the bundled entry",
  )

  TestSupport.assertTrue(NodeFs.existsSync(wrapperPath), "bundled CLI entry exists")

  let wrapperSource = NodeFs.readFileSyncUtf8(wrapperPath, "utf8")
  TestSupport.assertTrue(wrapperSource->TestSupport.startsWith("#!/usr/bin/env node\n"), "bundled CLI entry starts with a Node shebang")
  TestSupport.assertTrue(
    !(wrapperSource->TestSupport.includes("../src/Main.res.mjs")),
    "bundled CLI entry does not import the generated source entry",
  )

  let wrapperMode = NodeFs.statSync(wrapperPath)->NodeFs.mode
  TestSupport.assertTrue(wrapperMode->hasExecutableBit, "CLI wrapper is executable")

  let rootHelp = await importBinWithArgs(["--help"], "bin-test-root-help", wrapperPath, wrapperHref)
  TestSupport.assertTrue(
    rootHelp->runExitCode == None || rootHelp->runExitCode == Some(0),
    "bundled CLI help does not fail",
  )
  TestSupport.assertTrue(rootHelp->runStdout->TestSupport.includes("Commands:"), "bundled CLI help prints command list")

  let addHelp = await importBinWithArgs(["add", "--help"], "bin-test-add-help", wrapperPath, wrapperHref)
  TestSupport.assertTrue(addHelp->runExitCode == None || addHelp->runExitCode == Some(0), "add help exits successfully")
  TestSupport.assertTrue(
    addHelp->runStdout->TestSupport.includes("Usage: rescript-bindings add [options] [package]"),
    "add help shows optional package argument",
  )
  TestSupport.assertTrue(addHelp->runStdout->TestSupport.includes("--folder <path>"), "add help documents folder override")

  let legacyBinding = await importBinWithArgs(["binding", "publish"], "bin-test-legacy-binding", wrapperPath, wrapperHref)
  TestSupport.assertTrue(
    legacyBinding->runExitCode != None && legacyBinding->runExitCode != Some(0),
    "legacy binding namespace is rejected",
  )
  TestSupport.assertTrue(
    legacyBinding->runStderr->TestSupport.includes("unknown command 'binding'"),
    "legacy binding namespace prints an unknown command error",
  )

  let cliModule: cliModule = await importModule(cliHref ++ "?publish-auth-test")
  let runAuthCalled = ref(false)
  let loggedLines = await captureConsoleLog(async () => {
    await (cliModule->cliRunPublishAuthCheckWith)(async () => {
      runAuthCalled := true
      let identity: PublishAuthTypes.authIdentity = {
        githubLogin: Some("octocat"),
        displayName: None,
        email: None,
      }
      identity
    })
  })

  TestSupport.assertTrue(runAuthCalled.contents, "publish auth helper calls the auth implementation without URL configuration")
  TestSupport.assertTrue(
    loggedLines->TestSupport.some(line => line == "Authenticated as octocat"),
    "publish auth check logs the authenticated identity label",
  )

  Console.log("Bin_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(TestSupport.messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
