import { defineConfig } from "rolldown";

export default defineConfig({
  input: "src/worker-entry.mjs",
  platform: "browser",
  treeshake: true,
  output: {
    file: "dist/worker.mjs",
    format: "esm",
    minify: true,
  },
});
