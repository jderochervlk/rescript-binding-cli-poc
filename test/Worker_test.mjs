import worker from "../src/Worker.mjs"

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const encodeSegment = value => Buffer.from(JSON.stringify(value)).toString("base64url")

const makeJwt = payload =>
  `${encodeSegment({ alg: "none", typ: "JWT" })}.${encodeSegment(payload)}.signature`

const publicApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api"
const publishApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api/publish"

const releaseRow = {
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
}

const releaseFileRow = {
  release_id: "release-1",
  relative_path: "isEven.res",
  content: '@module("is-even")\nexternal isEven: int => bool = "default"\n',
  sha256: "file-sha",
  bytes: 61,
}

const fakeDb = {
  prepare: sql => ({
    bind: (...params) => ({
      all: async () => {
        if (sql.includes("FROM binding_releases") && params[0] === "is-even") {
          return { results: [releaseRow] }
        }

        if (sql.includes("FROM binding_files") && params[0] === "release-1") {
          return { results: [releaseFileRow] }
        }

        return { results: [] }
      },
      first: async () => {
        if (sql.includes("FROM binding_releases") && params[0] === "release-1") {
          return releaseRow
        }

        return null
      },
      run: async () => ({ success: true }),
    }),
  }),
  batch: async () => [],
}

const oldProtectedPath = await worker.fetch(new Request(`${publicApiBaseUrl}/v1/me`), {}, {})
assert(oldProtectedPath.status === 404, "publish identity route is not exposed under public api")

const publicList = await worker.fetch(
  new Request(
    `${publicApiBaseUrl}/v1/packages/is-even/releases?packageVersion=1.0.0&rescriptVersion=%5E12.0.0`
  ),
  { DB: fakeDb },
  {}
)

assert(publicList.status === 200, "public package release list is available")

const publicListBody = await publicList.json()
assert(publicListBody.releases?.length === 1, "public package release list returns releases")
assert(publicListBody.releases[0].id === "release-1", "public package release list maps release id")
assert(
  publicListBody.releases[0].compatibilityRank === 3,
  "public package release list includes compatibility rank"
)

const publicRelease = await worker.fetch(
  new Request(`${publicApiBaseUrl}/v1/releases/release-1`),
  { DB: fakeDb },
  {}
)

assert(publicRelease.status === 200, "public release payload is available")

const publicReleaseBody = await publicRelease.json()
assert(publicReleaseBody.id === "release-1", "public release payload maps release metadata")
assert(publicReleaseBody.files?.length === 1, "public release payload includes files")
assert(
  publicReleaseBody.files[0].relativePath === "isEven.res",
  "public release payload maps file paths"
)

const unauthorized = await worker.fetch(new Request(`${publishApiBaseUrl}/v1/me`), {}, {})
assert(unauthorized.status === 401, "missing access identity is rejected")

const malformed = await worker.fetch(
  new Request(`${publishApiBaseUrl}/v1/me`, {
    headers: {
      "Cf-Access-Jwt-Assertion": "not-a-jwt",
    },
  }),
  {},
  {}
)

assert(malformed.status === 401, "malformed access identity is rejected")

const publishUnauthorized = await worker.fetch(
  new Request(`${publishApiBaseUrl}/v1/releases`, { method: "POST" }),
  {},
  {}
)
assert(publishUnauthorized.status === 401, "publish route requires access identity")

const adminUnauthorized = await worker.fetch(
  new Request(`${publishApiBaseUrl}/v1/admin/publishers`, { method: "POST" }),
  {},
  {}
)
assert(adminUnauthorized.status === 401, "admin route requires access identity")

const authorized = await worker.fetch(
  new Request(`${publishApiBaseUrl}/v1/me`, {
    headers: {
      "Cf-Access-Jwt-Assertion": makeJwt({ email: "dev@example.com" }),
    },
  }),
  {},
  {}
)

assert(authorized.status === 200, "access jwt allows /v1/me")

const body = await authorized.json()
assert(body.email === "dev@example.com", "worker returns the email claim")
assert(body.githubLogin === null, "worker leaves github login null in this slice")
assert(body.displayName === null, "worker leaves display name null in this slice")
assert(body.access?.authenticated === true, "worker marks response as authenticated")

console.log("Worker_test.mjs passed")
