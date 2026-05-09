import { isProtectedRoute, routeFrom, validatePublishInput } from "./Worker.res.mjs"
import * as Validation from "./core/Validation.res.mjs"

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

const validationMessageFrom = error => error?._1 ?? error?.message ?? "Invalid publish payload"

const badRequest = message => json({ error: message }, 400)

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

const stringField = (payload, fieldName) => {
  const value = payload?.[fieldName]

  if (typeof value !== "string") {
    throw new Error(`${fieldName} is required`)
  }

  const trimmed = value.trim()
  if (trimmed === "") {
    throw new Error(`${fieldName} is required`)
  }

  return trimmed
}

const normalizePublishPayload = payload => {
  if (!Array.isArray(payload?.files)) {
    throw new Error("files is required")
  }

  return {
    packageName: stringField(payload, "packageName"),
    variantLabel: stringField(payload, "variantLabel"),
    peerPackageRange: stringField(payload, "peerPackageRange"),
    rescriptRange: stringField(payload, "rescriptRange"),
    description:
      typeof payload.description === "string" && payload.description.trim() !== ""
        ? payload.description.trim()
        : undefined,
    files: payload.files.map((file, index) => {
      if (typeof file?.relativePath !== "string" || typeof file?.content !== "string") {
        throw new Error(`files[${index}] must include relativePath and content`)
      }

      return {
        relativePath: file.relativePath,
        content: file.content,
      }
    }),
  }
}

const sha256Hex = async value => {
  const digest = await globalThis.crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value)
  )

  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("")
}

const publisherLabelFrom = identity =>
  identity.githubLogin ?? identity.email ?? identity.displayName ?? "unknown-user"

const decodePathValue = value => {
  try {
    return decodeURIComponent(value)
  } catch {
    throw new Error(`Invalid encoded path value: ${value}`)
  }
}

const releaseFromRow = row => ({
  id: row.id,
  packageName: row.package_name,
  variantLabel: row.variant_label,
  variantSlug: row.variant_slug,
  publisherLogin: row.publisher_login,
  publisherDisplayName: row.publisher_display_name,
  peerPackageRange: row.peer_package_range,
  rescriptRange: row.rescript_range,
  description: row.description,
  createdAt: row.created_at,
})

const releaseWithCompatibility = ({ row, packageVersion, rescriptVersion }) => {
  const release = releaseFromRow(row)
  const isPackageCompatible = packageVersion
    ? packageVersion === release.peerPackageRange
    : null
  const isRescriptCompatible = rescriptVersion
    ? rescriptVersion === release.rescriptRange
    : null

  return {
    ...release,
    isPackageCompatible,
    isRescriptCompatible,
    compatibilityRank:
      (isPackageCompatible === true ? 2 : 0) + (isRescriptCompatible === true ? 1 : 0),
  }
}

const handleListPackageReleases = async ({ env, packageName, url }) => {
  if (!env?.DB) {
    return json({ error: "D1 binding DB is not configured" }, 500)
  }

  let decodedPackageName
  try {
    decodedPackageName = decodePathValue(packageName)
  } catch (error) {
    return badRequest(error.message)
  }

  const packageVersion = url.searchParams.get("packageVersion")
  const rescriptVersion = url.searchParams.get("rescriptVersion")
  const { results } = await env.DB
    .prepare(
      `SELECT
        id,
        package_name,
        variant_label,
        variant_slug,
        publisher_login,
        publisher_display_name,
        peer_package_range,
        rescript_range,
        description,
        created_at
      FROM binding_releases
      WHERE package_name = ?
        AND status = 'published'
      ORDER BY created_at DESC`
    )
    .bind(decodedPackageName)
    .all()
  const releases = results
    .map(row => releaseWithCompatibility({ row, packageVersion, rescriptVersion }))
    .sort((a, b) => {
      if (b.compatibilityRank !== a.compatibilityRank) {
        return b.compatibilityRank - a.compatibilityRank
      }

      return b.createdAt.localeCompare(a.createdAt)
    })

  return json({ releases })
}

const handleGetRelease = async ({ env, releaseId }) => {
  if (!env?.DB) {
    return json({ error: "D1 binding DB is not configured" }, 500)
  }

  let decodedReleaseId
  try {
    decodedReleaseId = decodePathValue(releaseId)
  } catch (error) {
    return badRequest(error.message)
  }

  const row = await env.DB
    .prepare(
      `SELECT
        id,
        package_name,
        variant_label,
        variant_slug,
        publisher_login,
        publisher_display_name,
        peer_package_range,
        rescript_range,
        description,
        created_at
      FROM binding_releases
      WHERE id = ?
        AND status = 'published'`
    )
    .bind(decodedReleaseId)
    .first()

  if (!row) {
    return json({ error: "Release not found" }, 404)
  }

  const { results } = await env.DB
    .prepare(
      `SELECT
        relative_path,
        content,
        sha256,
        bytes
      FROM binding_files
      WHERE release_id = ?
      ORDER BY relative_path ASC`
    )
    .bind(decodedReleaseId)
    .all()

  return json({
    ...releaseFromRow(row),
    files: results.map(file => ({
      relativePath: file.relative_path,
      content: file.content,
      sha256: file.sha256,
      bytes: file.bytes,
    })),
  })
}

const insertRelease = async ({ db, input, files, identity }) => {
  const variantSlug = Validation.safeSlug(input.variantLabel)
  const filesWithSha = await Promise.all(
    files.map(async file => ({
      ...file,
      sha256: await sha256Hex(file.content),
    }))
  )
  const manifestSha256 = await sha256Hex(
    JSON.stringify({
      packageName: input.packageName,
      variantLabel: input.variantLabel,
      variantSlug,
      peerPackageRange: input.peerPackageRange,
      rescriptRange: input.rescriptRange,
      files: filesWithSha.map(file => ({
        relativePath: file.relativePath,
        sha256: file.sha256,
        bytes: file.bytes,
      })),
    })
  )
  const existing = await db
    .prepare(
      `SELECT id
       FROM binding_releases
       WHERE package_name = ?
         AND variant_slug = ?
         AND peer_package_range = ?
         AND rescript_range = ?
         AND manifest_sha256 = ?`
    )
    .bind(
      input.packageName,
      variantSlug,
      input.peerPackageRange,
      input.rescriptRange,
      manifestSha256
    )
    .first()

  if (existing?.id) {
    return {
      releaseId: existing.id,
      packageName: input.packageName,
      variantLabel: input.variantLabel,
      variantSlug,
      fileCount: filesWithSha.length,
      duplicate: true,
    }
  }

  const releaseId = globalThis.crypto.randomUUID()
  const auditId = globalThis.crypto.randomUUID()
  const createdAt = new Date().toISOString()
  const publisherLogin = publisherLabelFrom(identity)
  const publisherDisplayName = identity.displayName ?? publisherLogin

  await db.batch([
    db
      .prepare(
        `INSERT INTO binding_releases (
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
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        releaseId,
        input.packageName,
        input.variantLabel,
        variantSlug,
        publisherLogin,
        publisherDisplayName,
        input.peerPackageRange,
        input.rescriptRange,
        input.description ?? null,
        filesWithSha.length,
        manifestSha256,
        "published",
        createdAt
      ),
    ...filesWithSha.map(file =>
      db
        .prepare(
          `INSERT INTO binding_files (
            release_id,
            relative_path,
            content,
            sha256,
            bytes
          ) VALUES (?, ?, ?, ?, ?)`
        )
        .bind(releaseId, file.relativePath, file.content, file.sha256, file.bytes)
    ),
    db
      .prepare(
        `INSERT INTO publish_audit_log (
          id,
          release_id,
          publisher_login,
          action,
          created_at,
          metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?)`
      )
      .bind(
        auditId,
        releaseId,
        publisherLogin,
        "publish",
        createdAt,
        JSON.stringify({
          packageName: input.packageName,
          variantSlug,
          fileCount: filesWithSha.length,
        })
      ),
  ])

  return {
    releaseId,
    packageName: input.packageName,
    variantLabel: input.variantLabel,
    variantSlug,
    fileCount: filesWithSha.length,
    duplicate: false,
  }
}

const handlePublish = async ({ request, env, identity }) => {
  if (!env?.DB) {
    return json({ error: "D1 binding DB is not configured" }, 500)
  }

  let payload
  try {
    payload = await request.json()
  } catch {
    return badRequest("Request body must be JSON")
  }

  let input
  let files
  try {
    input = normalizePublishPayload(payload)
    files = validatePublishInput(input)
  } catch (error) {
    return badRequest(validationMessageFrom(error))
  }

  try {
    const result = await insertRelease({ db: env.DB, input, files, identity })
    return json(result, result.duplicate ? 200 : 201)
  } catch (error) {
    return json({ error: error?.message ?? "Publish failed" }, 500)
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url)
    const route = routeFrom(request.method, url.pathname)
    const identity = currentIdentity(request)

    if (isProtectedRoute(route) && !identity) {
      return json({ error: "Missing Access identity" }, 401)
    }

    if (typeof route === "object" && route.TAG === "ListPackageReleases") {
      return handleListPackageReleases({ env, packageName: route._0, url })
    }

    if (typeof route === "object" && route.TAG === "GetRelease") {
      return handleGetRelease({ env, releaseId: route._0 })
    }

    if (route === "Me") {
      return json(identity)
    }

    if (route === "Publish") {
      return handlePublish({ request, env, identity })
    }

    return json({ error: "Not found" }, 404)
  },
}
