type requestInit
type jsonBody
type release
type releaseFile
type accessBody

@new external makeRequest: string => Worker.request = "Request"
@new external makeRequestWithInit: (string, requestInit) => Worker.request = "Request"
@obj external requestInit: (~method: string=?, ~headers: 'headers=?, ~body: string=?, unit) => requestInit = ""
@get external responseStatus: Worker.response => int = "status"
@send external responseJson: Worker.response => promise<'body> = "json"
@get external releases: jsonBody => array<release> = "releases"
@get external files: jsonBody => array<releaseFile> = "files"
@get external id: jsonBody => string = "id"
@get external releaseId: jsonBody => string = "releaseId"
@get external duplicate: jsonBody => bool = "duplicate"
@get external email: accessBody => string = "email"
@get external githubLogin: accessBody => 'value = "githubLogin"
@get external displayName: accessBody => 'value = "displayName"
@get external access: accessBody => 'access = "access"
@get external authenticated: 'access => bool = "authenticated"
@get external releaseIdFromRelease: release => string = "id"
@get external compatibilityRank: release => int = "compatibilityRank"
@get external relativePath: releaseFile => string = "relativePath"

let isNull = value => {
  let _ = value
  %raw("value === null")
}

let makeJwt = payload => {
  let _ = payload
  %raw(`(() => {
    const encodeSegment = value => Buffer.from(JSON.stringify(value)).toString("base64url");
    return encodeSegment({ alg: "none", typ: "JWT" }) + "." + encodeSegment(payload) + ".signature";
  })()`)
}

let accessHeaders = jwt => {
  let _ = jwt
  %raw(`({ "Cf-Access-Jwt-Assertion": jwt })`)
}

let jsonAccessHeaders = jwt => {
  let _ = jwt
  %raw(`({ "Cf-Access-Jwt-Assertion": jwt, "content-type": "application/json" })`)
}

let emptyEnv: Worker.env = %raw(`({})`)
let ctx = %raw(`({})`)
let publicApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api"
let publishApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api/publish"

let fakeDb: Worker.env = %raw(`({
  DB: {
    prepare: sql => ({
      bind: (...params) => ({
        all: async () => {
          if (sql.includes("FROM binding_releases") && params[0] === "is-even") {
            return {
              results: [{
                id: "release-1",
                package_name: "is-even",
                variant_label: "isEven",
                variant_slug: "iseven",
                publisher_login: "dev@example.com",
                publisher_display_name: "Dev",
                peer_package_range: "1.0.0",
                rescript_range: "^12.0.0",
                description: "Fixture release",
                file_count: 1,
                manifest_sha256: "manifest-sha",
                status: "published",
                created_at: "2026-05-09T22:00:00.000Z",
              }],
            };
          }

          if (sql.includes("FROM binding_files") && params[0] === "release-1") {
            return {
              results: [{
                release_id: "release-1",
                relative_path: "isEven.res",
                content: '@module("is-even")\nexternal isEven: int => bool = "default"\n',
                sha256: "file-sha",
                bytes: 61,
              }],
            };
          }

          return { results: [] };
        },
        first: async () => {
          if (sql.includes("FROM binding_releases") && params[0] === "release-1") {
            return {
              id: "release-1",
              package_name: "is-even",
              variant_label: "isEven",
              variant_slug: "iseven",
              publisher_login: "dev@example.com",
              publisher_display_name: "Dev",
              peer_package_range: "1.0.0",
              rescript_range: "^12.0.0",
              description: "Fixture release",
              file_count: 1,
              manifest_sha256: "manifest-sha",
              status: "published",
              created_at: "2026-05-09T22:00:00.000Z",
            };
          }

          return null;
        },
        run: async () => ({ success: true }),
      }),
    }),
    batch: async () => [],
  },
})`)

let duplicatePublishDb: Worker.env = %raw(`({
  DB: {
    prepare: sql => ({
      bind: (...params) => ({
        all: async () => ({ results: [] }),
        first: async () => {
          if (sql.includes("SELECT id") && params[0] === "@inquirer/prompts") {
            return { id: "existing-release" };
          }

          return null;
        },
        run: async () => ({ success: true }),
      }),
    }),
    batch: async () => {
      throw new Error("duplicate publish should not insert rows");
    },
  },
})`)

let scopedPackageParam = ref("")
let scopedPackageDb: Worker.env = %raw(`({
    DB: {
      prepare: sql => ({
        bind: (...params) => ({
          all: async () => {
            if (sql.includes("FROM binding_releases")) {
              scopedPackageParam.contents = params[0];
            }

            return { results: [] };
          },
          first: async () => null,
          run: async () => ({ success: true }),
        }),
      }),
      batch: async () => [],
    },
  })`)

let run = async () => {
  let oldProtectedPath = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/me"), emptyEnv, ctx)
  TestSupport.assertTrue(responseStatus(oldProtectedPath) == 404, "publish identity route is not exposed under public api")

  let publicList = await Worker.fetch(
    makeRequest(publicApiBaseUrl ++ "/v1/packages/is-even/releases?packageVersion=1.0.0&rescriptVersion=%5E12.0.0"),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(publicList) == 200, "public package release list is available")

  let publicListMissingDb = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/packages/is-even/releases"), emptyEnv, ctx)
  TestSupport.assertTrue(responseStatus(publicListMissingDb) == 500, "public package release list requires D1 binding")

  let scopedPackageList = await Worker.fetch(
    makeRequest(publicApiBaseUrl ++ "/v1/packages/%40inquirer%2Fprompts/releases"),
    scopedPackageDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(scopedPackageList) == 200, "public package release list accepts encoded scoped packages")
  TestSupport.assertStringEquals(scopedPackageParam.contents, "@inquirer/prompts", "public package release list decodes scoped package names before querying")

  let publicListBody = await publicList->responseJson
  let publicReleases = publicListBody->releases
  TestSupport.assertTrue(publicReleases->Array.length == 1, "public package release list returns releases")
  TestSupport.assertStringEquals(publicReleases[0]->Belt.Option.getExn->releaseIdFromRelease, "release-1", "public package release list maps release id")
  TestSupport.assertTrue(publicReleases[0]->Belt.Option.getExn->compatibilityRank == 3, "public package release list includes compatibility rank")

  let publicRelease = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/releases/release-1"), fakeDb, ctx)
  TestSupport.assertTrue(responseStatus(publicRelease) == 200, "public release payload is available")

  let publicReleaseMissing = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/releases/missing-release"), fakeDb, ctx)
  TestSupport.assertTrue(responseStatus(publicReleaseMissing) == 404, "missing release payload returns 404")

  let publicReleaseBody = await publicRelease->responseJson
  TestSupport.assertStringEquals(publicReleaseBody->id, "release-1", "public release payload maps release metadata")
  let publicReleaseFiles = publicReleaseBody->files
  TestSupport.assertTrue(publicReleaseFiles->Array.length == 1, "public release payload includes files")
  TestSupport.assertStringEquals(
    publicReleaseFiles[0]->Belt.Option.getExn->relativePath,
    "isEven.res",
    "public release payload maps file paths",
  )

  let unauthorized = await Worker.fetch(makeRequest(publishApiBaseUrl ++ "/v1/me"), emptyEnv, ctx)
  TestSupport.assertTrue(responseStatus(unauthorized) == 401, "missing access identity is rejected")

  let malformed = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/me",
      requestInit(~headers=accessHeaders("not-a-jwt"), ()),
    ),
    emptyEnv,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(malformed) == 401, "malformed access identity is rejected")

  let publishUnauthorized = await Worker.fetch(
    makeRequestWithInit(publishApiBaseUrl ++ "/v1/releases", requestInit(~method="POST", ())),
    emptyEnv,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(publishUnauthorized) == 401, "publish route requires access identity")

  let publishBadJson = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases",
      requestInit(
        ~method="POST",
        ~headers=accessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body="not-json",
        (),
      ),
    ),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(publishBadJson) == 400, "publish route rejects invalid JSON")

  let publishBadPayload = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body=TestSupport.stringify({
          "packageName": "@inquirer/prompts",
          "variantLabel": "",
          "peerPackageRange": "^8.4.2",
          "rescriptRange": "^12.0.0",
          "files": [{"relativePath": "Binding.res", "content": "let x = 1\n"}],
        }),
        (),
      ),
    ),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(publishBadPayload) == 400, "publish route validates required payload fields")

  let duplicatePublish = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body=TestSupport.stringify({
          "packageName": "@inquirer/prompts",
          "variantLabel": "default",
          "peerPackageRange": "^8.4.2",
          "rescriptRange": "^12.0.0",
          "files": [{"relativePath": "Binding.res", "content": "let x = 1\n"}],
        }),
        (),
      ),
    ),
    duplicatePublishDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(duplicatePublish) == 200, "duplicate publish returns success without inserting")
  let duplicatePublishBody = await duplicatePublish->responseJson
  TestSupport.assertTrue(duplicatePublishBody->duplicate, "duplicate publish response is marked duplicate")
  TestSupport.assertStringEquals(duplicatePublishBody->releaseId, "existing-release", "duplicate publish returns the existing release id")

  let adminUnauthorized = await Worker.fetch(
    makeRequestWithInit(publishApiBaseUrl ++ "/v1/admin/publishers", requestInit(~method="POST", ())),
    emptyEnv,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(adminUnauthorized) == 401, "admin route requires access identity")

  let authorized = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/me",
      requestInit(~headers=accessHeaders(makeJwt({"email": "dev@example.com"})), ()),
    ),
    emptyEnv,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(authorized) == 200, "access jwt allows /v1/me")

  let body: accessBody = await authorized->responseJson
  TestSupport.assertStringEquals(body->email, "dev@example.com", "worker returns the email claim")
  TestSupport.assertTrue(body->githubLogin->isNull, "worker leaves github login null in this slice")
  TestSupport.assertTrue(body->displayName->isNull, "worker leaves display name null in this slice")
  TestSupport.assertTrue(body->access->authenticated, "worker marks response as authenticated")

  Console.log("Worker_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(TestSupport.messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
