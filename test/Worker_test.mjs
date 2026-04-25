import worker from "../src/Worker.mjs"

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const encodeSegment = value => Buffer.from(JSON.stringify(value)).toString("base64url")

const makeJwt = payload =>
  `${encodeSegment({ alg: "none", typ: "JWT" })}.${encodeSegment(payload)}.signature`

const unauthorized = await worker.fetch(new Request("https://publish.example.com/v1/me"), {}, {})
assert(unauthorized.status === 401, "missing access identity is rejected")

const malformed = await worker.fetch(
  new Request("https://publish.example.com/v1/me", {
    headers: {
      "Cf-Access-Jwt-Assertion": "not-a-jwt",
    },
  }),
  {},
  {}
)

assert(malformed.status === 401, "malformed access identity is rejected")

const publishUnauthorized = await worker.fetch(
  new Request("https://publish.example.com/v1/releases", { method: "POST" }),
  {},
  {}
)
assert(publishUnauthorized.status === 401, "publish route requires access identity")

const adminUnauthorized = await worker.fetch(
  new Request("https://publish.example.com/v1/admin/publishers", { method: "POST" }),
  {},
  {}
)
assert(adminUnauthorized.status === 401, "admin route requires access identity")

const authorized = await worker.fetch(
  new Request("https://publish.example.com/v1/me", {
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
