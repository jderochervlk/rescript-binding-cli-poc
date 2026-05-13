/* Bindings for jotai 2.20.0.

    Source evidence:
    - jotai/package.json exposes the root entrypoint with package-provided types.
    - jotai/index.d.ts re-exports jotai/vanilla and jotai/react.
    - atom overloads come from jotai/vanilla/atom.d.ts.
    - hooks and Provider come from jotai/react declaration files.

    Jotai's TypeScript types support variadic writable atom arguments and
    SetStateAction<Value> as Value | (Value => Value). This binding keeps the
    common direct-value and updater cases as distinct ReScript externals.
*/

type atom<'value>
type primitiveAtom<'value>
type writableAtom<'value, 'arg, 'result>
type store
type options
type readOptions
type unsubscribe = unit => unit

type getter<'value> = atom<'value> => 'value
type setter<'value> = (primitiveAtom<'value>, 'value) => unit
type setterWithUpdater<'value> = (primitiveAtom<'value>, 'value => 'value) => unit

type read<'dep, 'value> = (getter<'dep>, readOptions) => 'value
type write<'dep, 'setValue, 'arg, 'result> = (getter<'dep>, setter<'setValue>, 'arg) => 'result
type writeWithUpdater<'dep, 'setValue, 'arg, 'result> = (
  getter<'dep>,
  setterWithUpdater<'setValue>,
  'arg,
) => 'result

/* ReScript has no structural subtype relation between Atom, PrimitiveAtom, and
    WritableAtom, so these are explicit zero-cost upcasts for APIs that only
    need read access.
*/
external primitiveToAtom: primitiveAtom<'value> => atom<'value> = "%identity"
external writableToAtom: writableAtom<'value, 'arg, 'result> => atom<'value> = "%identity"

/* Creates a primitive atom from an initial value.

    Example:
    let countAtom = Jotai.atom(0)
*/
@module("jotai") external atom: 'value => primitiveAtom<'value> = "atom"

/* Creates a primitive atom whose initial JavaScript value is undefined.

    TypeScript declares this overload as atom<Value>(): PrimitiveAtom<Value | undefined>.
    The ReScript return type maps undefined to option.
*/
@module("jotai") external atomUndefined: unit => primitiveAtom<option<'value>> = "atom"

/* Creates a read-only derived atom. The getter type is intentionally simple:
    it works best when the read callback reads atoms with one value type.

    Example:
    let countAtom = Jotai.atom(0)
    let doubledAtom = Jotai.atomRead((get, _) => get(Jotai.primitiveToAtom(countAtom)) * 2)
*/
@module("jotai") external atomRead: read<'dep, 'value> => atom<'value> = "atom"

/* Creates a writable derived atom whose write callback accepts one argument.
    Jotai supports variadic write arguments; add a local external for advanced
    tuple-shaped writes.
*/
@module("jotai")
external atomReadWrite: (
  read<'dep, 'value>,
  write<'dep, 'setValue, 'arg, 'result>,
) => writableAtom<'value, 'arg, 'result> = "atom"

/* Writable derived atom variant for setting primitive atoms with updater
    functions.
*/
@module("jotai")
external atomReadWriteWithUpdater: (
  read<'dep, 'value>,
  writeWithUpdater<'dep, 'setValue, 'arg, 'result>,
) => writableAtom<'value, 'arg, 'result> = "atom"

@obj external options: (~store: store=?, unit) => options = ""

/* React hook for a primitive atom, returning the current value and a setter
    that accepts a direct value.

    Example:
    let (count, setCount) = Jotai.useAtom(countAtom)
    setCount(count + 1)
*/
@module("jotai") external useAtom: primitiveAtom<'value> => ('value, 'value => unit) = "useAtom"

@module("jotai")
external useAtomWithOptions: (primitiveAtom<'value>, options) => ('value, 'value => unit) =
  "useAtom"

/* React hook variant whose setter accepts an updater function. */
@module("jotai")
external useAtomWithUpdater: primitiveAtom<'value> => ('value, ('value => 'value) => unit) =
  "useAtom"

@module("jotai")
external useAtomWithUpdaterOptions: (
  primitiveAtom<'value>,
  options,
) => ('value, ('value => 'value) => unit) = "useAtom"

/* React hook for writable derived atoms with one write argument. */
@module("jotai")
external useWritableAtom: writableAtom<'value, 'arg, 'result> => ('value, 'arg => 'result) =
  "useAtom"

@module("jotai")
external useWritableAtomWithOptions: (
  writableAtom<'value, 'arg, 'result>,
  options,
) => ('value, 'arg => 'result) = "useAtom"

/* Reads an atom value in React. */
@module("jotai") external useAtomValue: atom<'value> => 'value = "useAtomValue"
@module("jotai")
external useAtomValueWithOptions: (atom<'value>, options) => 'value = "useAtomValue"
@module("jotai") external usePrimitiveAtomValue: primitiveAtom<'value> => 'value = "useAtomValue"

@module("jotai")
external usePrimitiveAtomValueWithOptions: (primitiveAtom<'value>, options) => 'value =
  "useAtomValue"

@module("jotai")
external useWritableAtomValue: writableAtom<'value, 'arg, 'result> => 'value = "useAtomValue"

@module("jotai")
external useWritableAtomValueWithOptions: (writableAtom<'value, 'arg, 'result>, options) => 'value =
  "useAtomValue"

/* Returns a setter for a primitive atom with a direct value. */
@module("jotai") external useSetAtom: primitiveAtom<'value> => 'value => unit = "useSetAtom"

@module("jotai")
external useSetAtomWithOptions: (primitiveAtom<'value>, options) => 'value => unit = "useSetAtom"

/* Returns a setter for a primitive atom with an updater function. */
@module("jotai")
external useSetAtomWithUpdater: primitiveAtom<'value> => ('value => 'value) => unit = "useSetAtom"

@module("jotai")
external useSetAtomWithUpdaterOptions: (
  primitiveAtom<'value>,
  options,
) => ('value => 'value) => unit = "useSetAtom"

/* Returns a setter for a writable derived atom with one write argument. */
@module("jotai")
external useSetWritableAtom: writableAtom<'value, 'arg, 'result> => 'arg => 'result = "useSetAtom"

@module("jotai")
external useSetWritableAtomWithOptions: (
  writableAtom<'value, 'arg, 'result>,
  options,
) => 'arg => 'result = "useSetAtom"

@module("jotai") external createStore: unit => store = "createStore"
@module("jotai") external getDefaultStore: unit => store = "getDefaultStore"
@module("jotai") external useStore: unit => store = "useStore"
@module("jotai") external useStoreWithOptions: options => store = "useStore"

@send external get: (store, atom<'value>) => 'value = "get"
@send external getPrimitive: (store, primitiveAtom<'value>) => 'value = "get"
@send external getWritable: (store, writableAtom<'value, 'arg, 'result>) => 'value = "get"

@send external set: (store, primitiveAtom<'value>, 'value) => unit = "set"
@send external setWithUpdater: (store, primitiveAtom<'value>, 'value => 'value) => unit = "set"
@send external setWritable: (store, writableAtom<'value, 'arg, 'result>, 'arg) => 'result = "set"

@send external sub: (store, atom<'value>, unit => unit) => unsubscribe = "sub"
@send external subPrimitive: (store, primitiveAtom<'value>, unit => unit) => unsubscribe = "sub"
@send
external subWritable: (store, writableAtom<'value, 'arg, 'result>, unit => unit) => unsubscribe =
  "sub"

module Provider = {
  /* React Provider for an optional custom store.

      Example:
      let store = Jotai.createStore()
      <Jotai.Provider store> <App /> </Jotai.Provider>
 */
  @module("jotai") @react.component
  external make: (~store: store=?, ~children: React.element=?) => React.element = "Provider"
}
