import { chmod } from "node:fs/promises"

await chmod(new URL("../bin/index.mjs", import.meta.url), 0o755)
