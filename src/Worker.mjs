import { isProtectedRoute, routeFrom } from "./Worker.res.mjs"

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  })

const decodeBase64Url = value => {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/")
  const padding = "=".repeat((4 - (normalized.length % 4)) % 4)
  return atob(normalized + padding)
}

const decodeJwtPayload = assertion => {
  const parts = assertion.split(".")
  if (parts.length < 2) {
    throw new Error("Invalid Access JWT")
  }

  return JSON.parse(decodeBase64Url(parts[1]))
}

const currentIdentity = request => {
  const assertion = request.headers.get("Cf-Access-Jwt-Assertion")
  if (!assertion) {
    return null
  }

  let payload
  try {
    payload = decodeJwtPayload(assertion)
  } catch {
    return null
  }

  return {
    githubLogin: null,
    displayName: null,
    email: payload.email ?? null,
    access: { authenticated: true },
  }
}

export default {
  async fetch(request) {
    const url = new URL(request.url)
    const route = routeFrom(request.method, url.pathname)
    const identity = currentIdentity(request)

    if (isProtectedRoute(route) && !identity) {
      return json({ error: "Missing Access identity" }, 401)
    }

    switch (route) {
      case "Me": {
        return json(identity)
      }
      default:
        return json({ error: "Not found" }, 404)
    }
  },
}
