import { Command } from "commander"
import { runAdd } from "./js/RegistryAdd.mjs"
import { runPublish } from "./js/PublishOAuth.mjs"

const red = value => `\x1b[31m${value}\x1b[0m`

export const makeProgram = ({ deps = {}, stdout = process.stdout, stderr = process.stderr } = {}) => {
  const program = new Command()

  program
    .name("rescript-bindings")
    .description("Install and publish ReScript source bindings")
    .version("0.1.0")
    .showHelpAfterError("(run with --help for usage)")
    .configureOutput({
      writeOut: value => stdout.write(value),
      writeErr: value => stderr.write(value),
      outputError: (value, write) => write(red(value)),
    })
    .exitOverride()

  program
    .command("add")
    .description("Install a published binding into the current project")
    .argument("<package>", "JavaScript package name to install bindings for")
    .option("-f, --folder <path>", "install into this folder instead of src/bindings/<package>/<variant>")
    .action(async (packageName, options) => {
      await runAdd(packageName, options.folder, { deps })
    })

  program
    .command("publish")
    .description("Publish local .res/.resi bindings")
    .action(async () => {
      await runPublish({ deps })
    })

  return program
}

export const run = async ({ argv = process.argv, deps = {} } = {}) => {
  const program = makeProgram({ deps })

  try {
    await program.parseAsync(argv)
  } catch (error) {
    if (error?.code === "commander.helpDisplayed" || error?.code === "commander.version") {
      return
    }

    if (error?.code?.startsWith?.("commander.")) {
      process.exitCode = error.exitCode ?? 1
      return
    }

    throw error
  }
}

run().catch(error => {
  console.error(error?.message ?? "Command failed")
  process.exitCode = 1
})
