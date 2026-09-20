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
@get external packageName: jsonBody => string = "packageName"
@get external duplicate: jsonBody => bool = "duplicate"
@get external overwrittenReleaseIds: jsonBody => array<string> = "overwrittenReleaseIds"
@get external deleted: jsonBody => bool = "deleted"
@get external adminPublisherGithubLogin: jsonBody => string = "githubLogin"
@get external adminPublisherEmail: jsonBody => string = "email"
@get external adminPublisherActive: jsonBody => bool = "active"
@get external email: accessBody => string = "email"
@get external githubLogin: accessBody => 'value = "githubLogin"
@get external displayName: accessBody => 'value = "displayName"
@get external access: accessBody => 'access = "access"
@get external authenticated: 'access => bool = "authenticated"
@get external publisherApproved: 'access => bool = "publisherApproved"
@get external admin: 'access => bool = "admin"
@get external releaseIdFromRelease: release => string = "id"
@get external compatibilityRank: release => int = "compatibilityRank"
@get external relativePath: releaseFile => string = "relativePath"
@get external requiredEnvDb: Worker.env => Worker.db = "DB"
@obj external makeEnv: unit => Worker.env = ""
@set external setEnvDb: (Worker.env, Worker.db) => unit = "DB"
@set external setEnvPublisherAdminIdentities: (Worker.env, string) => unit =
  "PUBLISHER_ADMIN_IDENTITIES"

let asAdminEnv = env => {
  let adminEnv = makeEnv()
  adminEnv->setEnvDb(env->requiredEnvDb)
  adminEnv->setEnvPublisherAdminIdentities("dev@example.com")
  adminEnv
}

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
let fakeDbBase = fakeDb
let fakeDb = asAdminEnv(fakeDb)

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
let duplicatePublishDb = asAdminEnv(duplicatePublishDb)

let overwrittenUpdateCount = ref(0)
let insertedPeerPackageRange = ref("")
let insertedRescriptRange = ref("")
let overwritePublishDb: Worker.env = %raw(`({
  DB: {
    prepare: sql => ({
      bind: (...params) => ({
        __sql: sql,
        __params: params,
        all: async () => {
          if (sql.includes("peer_package_range") && sql.includes("status = 'published'")) {
            return {
              results: [
                {
                  id: "old-compatible",
                  peer_package_range: "^7.0.10",
                  rescript_range: "^12.0.0",
                },
                {
                  id: "old-package-major-mismatch",
                  peer_package_range: "^8.0.0",
                  rescript_range: "^12.0.0",
                },
                {
                  id: "old-rescript-major-mismatch",
                  peer_package_range: "^7.0.0",
                  rescript_range: "^11.0.0",
                },
              ],
            };
          }

          return { results: [] };
        },
        first: async () => null,
        run: async () => ({ success: true }),
      }),
    }),
    batch: async statements => {
      overwrittenUpdateCount.contents = statements.filter(statement =>
        statement.__sql.includes("UPDATE binding_releases") &&
        statement.__params[0] === "overwritten" &&
        statement.__params[1] === "old-compatible"
      ).length;
      const insert = statements.find(statement => statement.__sql.includes("INSERT INTO binding_releases"));
      if (insert) {
        insertedPeerPackageRange.contents = insert.__params[6];
        insertedRescriptRange.contents = insert.__params[7];
      }
      return [];
    },
  },
})`)
let overwritePublishDb = asAdminEnv(overwritePublishDb)

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

let deleteUpdateCount = ref(0)
let myPublishedDb: Worker.env = %raw(`({
  DB: {
    prepare: sql => ({
      bind: (...params) => ({
        __sql: sql,
        __params: params,
        all: async () => {
          if (sql.includes("FROM binding_releases") && sql.includes("publisher_login = ?")) {
            return {
              results: [{
                id: "my-release",
                package_name: "is-even",
                variant_label: "Default",
                variant_slug: "default",
                publisher_login: "dev@example.com",
                publisher_display_name: "Dev",
                peer_package_range: "^1.0.0",
                rescript_range: "^12.0.0",
                description: null,
                created_at: "2026-05-09T22:00:00.000Z",
              }],
            };
          }

          return { results: [] };
        },
        first: async () => {
          if (
            sql.includes("FROM binding_releases") &&
            sql.includes("publisher_login = ?") &&
            params[0] === "my-release" &&
            params[1] === "dev@example.com"
          ) {
            return {
              id: "my-release",
              package_name: "is-even",
              variant_label: "Default",
              variant_slug: "default",
              publisher_login: "dev@example.com",
              publisher_display_name: "Dev",
              peer_package_range: "^1.0.0",
              rescript_range: "^12.0.0",
              description: null,
              created_at: "2026-05-09T22:00:00.000Z",
            };
          }

          return null;
        },
        run: async () => ({ success: true }),
      }),
    }),
    batch: async statements => {
      deleteUpdateCount.contents = statements.filter(statement =>
        statement.__sql.includes("UPDATE binding_releases") &&
        statement.__params[0] === "deleted" &&
        statement.__params[1] === "my-release" &&
        statement.__params[2] === "dev@example.com"
      ).length;
      return [];
    },
  },
})`)
let myPublishedDb = asAdminEnv(myPublishedDb)

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

  let publishUnapproved = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "unapproved@example.com"})),
        ~body=TestSupport.stringify({
          "packageName": "is-even",
          "variantLabel": "default",
          "peerPackageRange": "^1.0.0",
          "rescriptRange": "^12.0.0",
          "files": [{"relativePath": "Binding.res", "content": "let x = 1\n"}],
        }),
        (),
      ),
    ),
    fakeDbBase,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(publishUnapproved) == 403, "authenticated but unapproved publishers are rejected")

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

  let overwritePublish = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body=TestSupport.stringify({
          "packageName": "@inquirer/prompts",
          "variantLabel": "default",
          "peerPackageRange": ">=7.1 <8",
          "rescriptRange": "12",
          "files": [{"relativePath": "Binding.res", "content": "let x = 1\n"}],
        }),
        (),
      ),
    ),
    overwritePublishDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(overwritePublish) == 201, "compatible overwrite publish inserts a new release")
  let overwritePublishBody = await overwritePublish->responseJson
  TestSupport.assertTrue(
    overwritePublishBody->overwrittenReleaseIds->Array.length == 1,
    "compatible overwrite response lists the overwritten release",
  )
  TestSupport.assertStringEquals(
    (overwritePublishBody->overwrittenReleaseIds)[0]->Belt.Option.getExn,
    "old-compatible",
    "compatible overwrite matches package and ReScript major lines",
  )
  TestSupport.assertStringEquals(
    insertedPeerPackageRange.contents,
    ">=7.1.0 <8.0.0",
    "publish normalizes package version range before insert",
  )
  TestSupport.assertStringEquals(
    insertedRescriptRange.contents,
    "12.0.0",
    "publish normalizes ReScript version range before insert",
  )
  TestSupport.assertTrue(
    overwrittenUpdateCount.contents == 1,
    "compatible overwrite only marks matching published releases overwritten",
  )

  let myPublished = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases",
      requestInit(~headers=accessHeaders(makeJwt({"email": "dev@example.com"})), ()),
    ),
    myPublishedDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(myPublished) == 200, "my published releases are listed")
  let myPublishedBody = await myPublished->responseJson
  TestSupport.assertTrue(myPublishedBody->releases->Array.length == 1, "my published release list returns rows")
  TestSupport.assertStringEquals(
    (myPublishedBody->releases)[0]->Belt.Option.getExn->releaseIdFromRelease,
    "my-release",
    "my published release list maps release ids",
  )

  let deletePublished = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases/my-release",
      requestInit(
        ~method="DELETE",
        ~headers=accessHeaders(makeJwt({"email": "dev@example.com"})),
        (),
      ),
    ),
    myPublishedDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(deletePublished) == 200, "owner can delete a published release")
  let deletePublishedBody = await deletePublished->responseJson
  TestSupport.assertTrue(deletePublishedBody->deleted, "delete response is marked deleted")
  TestSupport.assertStringEquals(deletePublishedBody->releaseId, "my-release", "delete response returns release id")
  TestSupport.assertTrue(deleteUpdateCount.contents == 1, "delete marks the release deleted")

  let deleteMissing = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/releases/missing-release",
      requestInit(
        ~method="DELETE",
        ~headers=accessHeaders(makeJwt({"email": "dev@example.com"})),
        (),
      ),
    ),
    myPublishedDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(deleteMissing) == 404, "delete only affects owned published releases")

  let adminUnauthorized = await Worker.fetch(
    makeRequestWithInit(publishApiBaseUrl ++ "/v1/admin/publishers", requestInit(~method="POST", ())),
    emptyEnv,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(adminUnauthorized) == 401, "admin route requires access identity")

  let adminForbidden = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/admin/publishers",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "unapproved@example.com"})),
        ~body=TestSupport.stringify({"githubLogin": "new-publisher", "active": true}),
        (),
      ),
    ),
    fakeDbBase,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(adminForbidden) == 403, "publisher administration requires a configured admin")

  let adminUpsert = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/admin/publishers",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body=TestSupport.stringify({
          "githubLogin": "New-Publisher",
          "email": "Publisher@Example.com",
          "active": true,
        }),
        (),
      ),
    ),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(adminUpsert) == 200, "configured admin can approve a publisher")
  let adminUpsertBody: jsonBody = await adminUpsert->responseJson
  TestSupport.assertStringEquals(
    adminUpsertBody->adminPublisherGithubLogin,
    "new-publisher",
    "publisher login is normalized before it is used as the upsert key",
  )
  TestSupport.assertStringEquals(
    adminUpsertBody->adminPublisherEmail,
    "publisher@example.com",
    "publisher email is normalized before storage",
  )
  TestSupport.assertTrue(adminUpsertBody->adminPublisherActive, "publisher is activated")

  let missingPublisherEmail = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/admin/publishers",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body=TestSupport.stringify({"githubLogin": "login-only", "active": true}),
        (),
      ),
    ),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(
    responseStatus(missingPublisherEmail) == 400,
    "publisher approval requires an email until GitHub login claims are available",
  )

  let invalidPublisherActive = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/admin/publishers",
      requestInit(
        ~method="POST",
        ~headers=jsonAccessHeaders(makeJwt({"email": "dev@example.com"})),
        ~body=TestSupport.stringify({
          "githubLogin": "new-publisher",
          "email": "publisher@example.com",
          "active": "false",
        }),
        (),
      ),
    ),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(
    responseStatus(invalidPublisherActive) == 400,
    "publisher approval rejects a non-boolean active value",
  )

  let unapprovedMe = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/me",
      requestInit(~headers=accessHeaders(makeJwt({"email": "unapproved@example.com"})), ()),
    ),
    fakeDbBase,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(unapprovedMe) == 200, "authenticated identities can inspect publisher approval")
  let unapprovedBody: accessBody = await unapprovedMe->responseJson
  TestSupport.assertTrue(
    !(unapprovedBody->access->publisherApproved),
    "unapproved identity is reported by /v1/me",
  )

  let authorized = await Worker.fetch(
    makeRequestWithInit(
      publishApiBaseUrl ++ "/v1/me",
      requestInit(~headers=accessHeaders(makeJwt({"email": "dev@example.com"})), ()),
    ),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(authorized) == 200, "access jwt allows /v1/me")

  let body: accessBody = await authorized->responseJson
  TestSupport.assertStringEquals(body->email, "dev@example.com", "worker returns the email claim")
  TestSupport.assertTrue(body->githubLogin->isNull, "worker leaves github login null in this slice")
  TestSupport.assertTrue(body->displayName->isNull, "worker leaves display name null in this slice")
  TestSupport.assertTrue(body->access->authenticated, "worker marks response as authenticated")
  TestSupport.assertTrue(body->access->publisherApproved, "configured admin is approved to publish")
  TestSupport.assertTrue(body->access->admin, "configured admin is identified by /v1/me")

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
