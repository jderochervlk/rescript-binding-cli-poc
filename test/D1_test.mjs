import { execSync } from "node:child_process"
import { readFileSync } from "node:fs"

const DB_NAME = "rescript-binding-registry"

const run = command => execSync(command, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] })

const parseWranglerJson = output => {
  const start = output.indexOf("[")
  if (start < 0) {
    throw new Error(`Could not find JSON output in wrangler response:\n${output}`)
  }

  return JSON.parse(output.slice(start))
}

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const execLocalSql = sql => {
  const escapedSql = sql.replace(/"/g, '\\"')
  const output = run(
    `npx wrangler d1 execute ${DB_NAME} --local --command "${escapedSql}"`
  )
  return parseWranglerJson(output)
}

const releaseId = `rel-${Date.now()}`
const createdAt = new Date().toISOString()
const bindingSource = readFileSync("test/fixtures/isEven.res", "utf8")
const escapedContent = bindingSource.replace(/'/g, "''")

run(`npx wrangler d1 execute ${DB_NAME} --local --file schema.sql`)

execLocalSql(`
DELETE FROM binding_files;
DELETE FROM publish_audit_log;
DELETE FROM binding_releases;
DELETE FROM approved_publishers;

INSERT INTO binding_releases (
  id,
  package_name,
  variant_label,
  variant_slug,
  publisher_login,
  publisher_display_name,
  peer_package_range,
  rescript_range,
  description,
  file_count,
  manifest_sha256,
  status,
  created_at
) VALUES (
  '${releaseId}',
  'is-even',
  'isEven',
  'iseven',
  'local-dev',
  'Local Dev',
  '^1.0.0',
  '>=12.0.0',
  'Dummy fixture release',
  1,
  'dummy-sha256',
  'published',
  '${createdAt}'
);

INSERT INTO binding_files (
  release_id,
  relative_path,
  content,
  sha256,
  bytes
) VALUES (
  '${releaseId}',
  'isEven.res',
  '${escapedContent}',
  'dummy-file-sha',
  ${bindingSource.length}
);

SELECT
  (SELECT COUNT(*) FROM binding_releases WHERE package_name = 'is-even') AS release_count,
  (SELECT COUNT(*) FROM binding_files WHERE release_id = '${releaseId}') AS file_count;
`)

const verify = execLocalSql(`
SELECT
  package_name,
  variant_label,
  file_count
FROM binding_releases
WHERE id = '${releaseId}';
`)

const row = verify?.[0]?.results?.[0]
assert(row?.package_name === "is-even", "release row exists for dummy is-even package")
assert(row?.variant_label === "isEven", "release uses isEven variant label")
assert(row?.file_count === 1, "release tracks one file")

const fileCheck = execLocalSql(`
SELECT
  relative_path,
  bytes
FROM binding_files
WHERE release_id = '${releaseId}';
`)

const fileRow = fileCheck?.[0]?.results?.[0]
assert(fileRow?.relative_path === "isEven.res", "binding file inserted")
assert(fileRow?.bytes === bindingSource.length, "binding file byte count persisted")

console.log("D1_test.mjs passed")
