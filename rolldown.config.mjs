import { defineConfig } from "rolldown";

export default defineConfig({
    input: "src/Main.res.mjs",
    platform: "node",
    external: [/^node:/],
    treeshake: true,
    output: {
        file: "bin/index.mjs",
        format: "esm",
        banner: () => "#!/usr/bin/env node",
        minify: true,
    },
});
