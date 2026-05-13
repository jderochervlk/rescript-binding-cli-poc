===============
RESCRIPT RULES
===============
- Use ReScript v12 unless the user explicitly asks for another version.
- Use modern ReScript syntax, not ReasonML syntax.
- Use rescript.json, not bsconfig.json.
- Use Stdlib modules and current APIs. Do not use legacy Belt or Js modules.
- Do not use old bs.* attributes. Use @module, @val, @send, @scope, @new, @string, @unwrap, and @as.
- Do not use %raw, %%raw, Obj.magic, or JavaScript shim files unless explicitly requested.
- Prefer pattern matching, variants, records, option, result, pipe functions, and small typed modules.
- Prefer Result for recoverable failures instead of throwing exceptions.
- Use JSON.t, JSON.parseOrThrow, and documented JSON constructors.
- Use async/await and Promise APIs from the v12 docs for promise code.
- For arrays, remember indexed access and Array.get return option values.
- For JavaScript bindings, keep externals minimal, typed, and reviewed.
- For React, use ReScript JSX v4 and wrap primitive children with React.string, React.int, React.float, or React.array.
- For React, make sure components have a .resi file with a single react component for HMR to work correctly
