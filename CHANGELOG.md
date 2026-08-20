# Changelog

## 1.0.0

The first version of `@scribe/builder`, the library that reads the packages a framework checkout holds and writes what
the rest of the toolchain obeys. It is imported, never typed: `scribedev` is the command line the framework is
maintained with.

### `@scribe/builder`

The half a package carries into the project that mounts it. It opens no file and reaches nothing outside the process,
which is what lets a package depend on it without dragging a toolchain along.

`Package` declares a manifest one step at a time, in the order a package's life takes: `named`, `describedAs`,
`version`, `dependsOn`, `build`. Each step answers only what may legally follow it, so the order is a matter of types
rather than of convention and no step can be taken twice. What comes out is frozen.

`mount` puts a manifest back together with the steps its entry exports, and is what the generated registrations call
once per mounted package. The three moments are `wires`, at import, `starts`, after boot, and `stops`, at shutdown. A
package may export none of them.

`Version` reads three numbers and nothing else, no pre-release suffix. `Constraint` reads three forms: a caret, an exact
version, and any number of `>=`, `<=`, `>` and `<` bounds spelled side by side. A union is refused.

Everything raised on purpose descends from `BuilderError`, so a caller can tell a fault in what somebody wrote from a
fault in this code, which keeps its stack trace.

### `@scribe/builder/tools`

The half that touches the disk and never leaves the toolchain.

`emit` is the operation of the library. It discovers the packages under the roots, resolves what the wants pull in, and
writes four files: `imports.json`, `resolution.json`, `registrations.ts` and `scribe.lock`. What they are called is
settled here rather than by each caller, since they are read by Deno, by the CLI that renders a project and by the host.

Every emitter comes in a pair, one that builds the value and one that writes it: `importMapFor` and `writeImportMap`,
`resolutionDocument` and `writeResolution`, `registrationsSource` and `writeRegistrations`, `lockText` and `writeLock`.

`discover` walks the roots and stops at a package instead of entering it, because a package's own subdirectories carry
the same names it does. Nothing executes a package: a manifest is read as text and a tree is read as files, so a broken
package is a message rather than whatever its code would have done on import.

`resolve` settles one version per package, backtracking when the first version it took leaves nothing, and names both
packages that asked when two majors of the same one are wanted at once.

### What a manifest holds

Four keys, and no others: `name`, `description`, `version`, `dependencies`. Everything a package used to write down
about its own tree is read off that tree instead, because a path that has to be declared as well as laid out is a chance
for the two to disagree, and the one that loses is always the tree.

A name is lowercase letters and single underscores, starting and ending with a letter. The names `app`, `core`,
`generated`, `host` and `scribe` are refused, since each already resolves to something else.

### What the map grants, and what it closes

A package's scope holds the packages it declared and whatever it writes outside the framework that the workspace has
settled. A consumer, which is the project's own code, gets the packages the project named and the whole of what the
workspace settled.

Two things are closed there rather than by a rule somebody has to run. Only the entries a package exports are written,
so `@scribe/realtime/src/anything.ts` resolves nowhere. And every grant sits in the scope of the directory that declared
it, so a package pulled in behind another is on disk, is mounted, and is unreachable from code that did not ask for it.
Both failures read as Deno's own `not a dependency and not in import map`.

`@scribe/builder` itself is the one thing that resolves from anywhere, since every package reaches it to declare itself.
It is named by the caller, either as a path on this machine or as a specifier carrying a scheme, such as
`jsr:@scribe/builder@1.0.0`.

### `examples/`

A workspace of two packages and a project that mounts one of them, plus the twenty lines that call `emit`. It runs, and
`deno task example:test` writes the four files and then runs every test through the map it just wrote.

### How this file gets written

The CI writes it. When a push to `dev` carries a version that moved, it reads every commit since the last tag, groups
them by their tag, writes the section, and only then names that commit. The commits that only raise the version or write
this file are left out.

What you write is the commit message. The section is made of them.
