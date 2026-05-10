@module("node:child_process") external execSync: (string, 'options) => string = "execSync"
@module("node:fs") external readFileSync: (string, string) => string = "readFileSync"

@send external indexOf: (string, string) => int = "indexOf"
@send external sliceFrom: (string, int) => string = "slice"

let dbName = "rescript-binding-registry"

let run = command =>
  execSync(command, {"encoding": "utf8", "stdio": ["ignore", "pipe", "pipe"]})

let parseWranglerJson = output => {
  let start = output->indexOf("[")
  if start < 0 {
    throw(Failure("Could not find JSON output in wrangler response:\n" ++ output))
  }

  TestSupport.parse(output->sliceFrom(start))
}

let execLocalSql = sql => {
  let escapedSql = sql->TestSupport.replaceAll("\"", "\\\"")
  let output = run("pnpm exec wrangler d1 execute " ++ dbName ++ " --local --command \"" ++ escapedSql ++ "\"")
  parseWranglerJson(output)
}

type queryResponse<'row> = {results: array<'row>}
type releaseRow = {
  package_name: string,
  variant_label: string,
  file_count: int,
}
type fileRow = {
  relative_path: string,
  bytes: int,
}
type fileContentRow = {content: string}

let firstResult = response => {
  let result: queryResponse<'row> = response[0]->Belt.Option.getExn
  result.results[0]->Belt.Option.getExn
}

let () = {
  let releaseId = "rel-" ++ (Date.now()->Float.toString)
  let createdAt = Date.make()->Date.toISOString
  let bindingSource = readFileSync("test/fixtures/isEven.res", "utf8")
  TestSupport.assertTrue(
    bindingSource->TestSupport.includes("@module(\"is-even\")"),
    "fixture binds to external is-even npm package",
  )
  let escapedContent = bindingSource->TestSupport.replaceAll("'", "''")

  run("pnpm exec wrangler d1 execute " ++ dbName ++ " --local --file schema.sql")->ignore

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
  '` ++ releaseId ++ `',
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
  '` ++ createdAt ++ `'
);

INSERT INTO binding_files (
  release_id,
  relative_path,
  content,
  sha256,
  bytes
) VALUES (
  '` ++ releaseId ++ `',
  'isEven.res',
  '` ++ escapedContent ++ `',
  'dummy-file-sha',
  ` ++ (bindingSource->String.length->Int.toString) ++ `
);

SELECT
  (SELECT COUNT(*) FROM binding_releases WHERE package_name = 'is-even') AS release_count,
  (SELECT COUNT(*) FROM binding_files WHERE release_id = '` ++ releaseId ++ `') AS file_count;
`)->ignore

  let verify: array<queryResponse<releaseRow>> = execLocalSql(`
SELECT
  package_name,
  variant_label,
  file_count
FROM binding_releases
WHERE id = '` ++ releaseId ++ `';
`)
  let row = firstResult(verify)
  TestSupport.assertStringEquals(row.package_name, "is-even", "release row exists for dummy is-even package")
  TestSupport.assertStringEquals(row.variant_label, "isEven", "release uses isEven variant label")
  TestSupport.assertTrue(row.file_count == 1, "release tracks one file")

  let fileCheck: array<queryResponse<fileRow>> = execLocalSql(`
SELECT
  relative_path,
  bytes
FROM binding_files
WHERE release_id = '` ++ releaseId ++ `';
`)
  let fileRow = firstResult(fileCheck)
  TestSupport.assertStringEquals(fileRow.relative_path, "isEven.res", "binding file inserted")
  TestSupport.assertTrue(fileRow.bytes == bindingSource->String.length, "binding file byte count persisted")

  let storedFile: array<queryResponse<fileContentRow>> = execLocalSql(`
SELECT content
FROM binding_files
WHERE release_id = '` ++ releaseId ++ `' AND relative_path = 'isEven.res';
`)
  let storedContent = firstResult(storedFile)
  TestSupport.assertStringEquals(
    storedContent.content,
    bindingSource,
    "stored file content matches fixture",
  )

  Console.log("D1_test.res passed")
}
