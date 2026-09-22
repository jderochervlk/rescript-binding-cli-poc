import { execFile } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const packageRoot = fileURLToPath(new URL("..", import.meta.url));

async function run(command, args, options = {}) {
  return execFileAsync(command, args, {
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
    ...options,
  });
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const temporaryRoot = await mkdtemp(join(tmpdir(), "rescript-bindings-package-"));

try {
  const packDirectory = join(temporaryRoot, "pack");
  const installDirectory = join(temporaryRoot, "install");
  await mkdir(packDirectory);
  await mkdir(installDirectory);

  const { stdout: packOutput } = await run(
    "npm",
    ["pack", "--json", "--ignore-scripts", "--pack-destination", packDirectory],
    { cwd: packageRoot },
  );
  const [packedPackage] = JSON.parse(packOutput);
  assert(packedPackage?.filename, "npm pack did not report a tarball filename");

  await writeFile(
    join(installDirectory, "package.json"),
    JSON.stringify({ name: "package-smoke-test", private: true }),
  );

  const tarballPath = join(packDirectory, packedPackage.filename);
  await run(
    "npm",
    [
      "install",
      "--offline",
      "--ignore-scripts",
      "--no-audit",
      "--no-fund",
      "--package-lock=false",
      tarballPath,
    ],
    { cwd: installDirectory },
  );

  const sourceManifest = JSON.parse(await readFile(join(packageRoot, "package.json"), "utf8"));
  const installedPackageRoot = join(installDirectory, "node_modules", "@jvlk", "rescript-bindings");
  const installedManifest = JSON.parse(
    await readFile(join(installedPackageRoot, "package.json"), "utf8"),
  );

  assert(
    installedManifest.version === sourceManifest.version,
    `installed version ${installedManifest.version} did not match ${sourceManifest.version}`,
  );
  assert(
    Object.keys(installedManifest.dependencies ?? {}).length === 0,
    "published CLI must not have runtime package dependencies",
  );
  assert(
    installedManifest.bin === "./bin/index.mjs",
    "published CLI must expose the rescript-bindings executable",
  );

  const installedEntryPoint = join(installedPackageRoot, "bin", "index.mjs");
  const entryPointStats = await stat(installedEntryPoint);
  assert(entryPointStats.isFile(), "published CLI entry point is missing");

  const { stdout: helpOutput } = await run(process.execPath, [installedEntryPoint, "--help"], {
    cwd: installDirectory,
  });
  assert(
    helpOutput.includes("Usage: rescript-bindings"),
    "installed CLI did not produce the expected help output",
  );

  process.stdout.write(
    `Verified clean install of @jvlk/rescript-bindings@${installedManifest.version}\n`,
  );
} finally {
  await rm(temporaryRoot, { recursive: true, force: true });
}
