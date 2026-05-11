---
name: rescript-bindings-generator
description: Use when creating ReScript bindings for a named JavaScript, TypeScript, or npm package. Guides package installation, declaration/source inspection, conservative ReScript type mapping, overload naming, examples, and keeping the binding in one package-named .res file.
---

# ReScript Bindings Generator

Create a small, usable ReScript binding for a named JavaScript package. Prefer a correct narrow surface over a broad mechanical port.

## Workflow

1. Identify the target package name, intended entrypoint, and output location. Ask only if any of these are ambiguous.
2. Install the package locally with the correct package manager:
   - `pnpm-lock.yaml` or `pnpm-workspace.yaml`: use `pnpm`.
   - `yarn.lock`: use `yarn`.
   - `package-lock.json`: use `npm`.
   - `bun.lock` or `bun.lockb`: use `bun`.
   - No lockfile: use the package manager declared in `packageManager`, otherwise default to `npm`.
3. Inspect package type information in this order:
   - Package-provided declarations from `package.json` fields such as `types`, `typings`, and typed `exports`, plus any generated `*.d.ts` files shipped with the package.
   - `@types/*` fallback. For scoped packages, check `@types/scope__name`.
   - Raw JavaScript source, package docs, and examples when no declarations are available.
4. Generate one ReScript file. The filename must be a ReScript-safe PascalCase module name derived from the package name, for example `jotai` -> `Jotai.res` and `foo` -> `Foo.res`. For scoped packages, include the scope only when it avoids ambiguity.
5. Add comments and small usage examples. Comments should document source evidence, important runtime behavior, and any intentionally omitted or simplified typing.
6. Format and verify with the local ReScript build or formatter when available.

Do not keep package-manager side effects unless the user wants the package added to the project. A temporary inspection install is fine.

## Binding Rules

Use the most basic ReScript type that represents the public API safely:

- TypeScript `number` -> `int`.
- TypeScript `string` -> `string`.
- TypeScript `boolean` -> `bool`.
- TypeScript `null` -> `Null.t<value>`.
- TypeScript `undefined` -> `option<value>`.
- TypeScript `null | undefined` -> `Nullable.t<value>`.
- Arrays and readonly arrays -> `array<value>`.
- Complex public objects -> records only when the shape is stable and useful; otherwise use opaque `type t`.
- Unknown, unconstrained generic, or very dynamic values -> prefer an opaque type or `Js.Json.t` with a comment explaining the limitation.

Keep the generated surface idiomatic for ReScript rather than mirroring every TypeScript detail. Avoid binding internal, deprecated, or undocumented exports unless the user requested them.

## Externals

Prefer direct externals with explicit module annotations:

```rescript
@module("foo") external make: unit => t = "make"
@module("foo") external fromString: string => t = "fromString"
```

For overloads, create distinct ReScript binding names that describe the accepted input while pointing at the same JavaScript export:

```rescript
@module("foo") external functionWithString: string => result = "function"
@module("foo") external functionWithNumber: int => result = "function"
```

Do not encode materially different overloads as one weakly typed external. Only use optional arguments for truly optional JavaScript parameters.

## Comments And Examples

Include short comments where they help a user understand the binding:

```rescript
/** Creates an atom from an initial value.

    Example:
    let count = Jotai.atom(0)
*/
@module("jotai") external atom: 'value => atom<'value> = "atom"
```

Examples should compile in spirit, stay close to real package usage, and avoid inventing large helper APIs. If the package has multiple primary workflows, include one example per workflow.

## Final Check

Before finishing, confirm:

- The binding is in one `.res` file named after the package.
- The selected package manager was used for inspection.
- Declaration files were checked before `@types/*`, and both were checked before raw JavaScript.
- Nullish values follow `Null.t`, `option`, and `Nullable.t` exactly.
- Function overloads have distinct ReScript names.
- Comments or examples show how to use the main bindings.
