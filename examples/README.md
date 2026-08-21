# A workspace, and what the builder makes of it

Two packages and a project that mounts one of them. Everything here runs, and running it is the point: the four files
under `.scribe/` are what the rest of the toolchain obeys, and reading them next to the sources they came from is the
shortest way to see what this library does.

```
deno task example        writes .scribe/ and says what it settled on
deno task example:test   writes it, then runs every test through the map it wrote
```

## What is here

```
packages/audiences/      a package that depends on nothing
packages/realtime/       a package that depends on audiences
app/                     the project's own code, which is not a package
build.ts                 the twenty lines that call emit
```

`build.ts` names `realtime` and nothing else. `audiences` is on disk and gets mounted anyway, because realtime asked for
it:

```
$ deno task example
audiences 1.0.0 transitive
realtime 1.2.0 direct
```

## What each piece is there to show

**A manifest holds four keys and no more.** `packages/realtime/package.yaml` is the whole of what realtime writes down
about itself. Everything else about it is read off its tree: where its entry is, what it exports, what SQL it poses,
what it imports from outside the framework. A path that had to be declared as well as laid out would be a chance for the
two to disagree, and the tree is what actually runs.

**A package has one way in.** `lib/realtime.ts` is it, and the layout decides that from the name. `lib/src/channel.ts`
holds the code, and the generated map carries no entry that reaches it, so it is private without a rule that says so.

**A package reaches what it declared, and nothing else.** The map puts realtime's grants in realtime's own scope:

```json
"../packages/realtime/": {
  "@scribe/audiences": "../packages/audiences/lib/audiences.ts",
  "@std/assert": "jsr:@std/assert@1"
}
```

Take `audiences` out of realtime's `dependencies` and `lib/src/channel.ts` stops resolving, with Deno's own
`Import "@scribe/audiences" not a dependency and not in import map`.

**A project reaches what it named, and not what came in behind it.** `app/` is a consumer, so it gets
`@scribe/realtime`, the `./testing` entry realtime exposes, and whatever the workspace settled outside the framework. It
does not get `@scribe/audiences`, which no one in `app/` ever named.

**A package may hand out a stub.** `packages/realtime/tests/testing/realtime.ts` is named after its package and sits in
`tests/testing/`, so it answers `@scribe/realtime/testing`. `app/main.test.ts` uses it, which is the whole reason that
directory exists.

**Mounting happens dependency first.** `.scribe/registrations.ts` imports audiences before realtime, so a `starts` step
never runs before the packages it was allowed to import have run theirs.

## What `.scribe/` holds

| File               | Who reads it                                                                      |
| ------------------ | --------------------------------------------------------------------------------- |
| `imports.json`     | Deno, as the import map of the run                                                |
| `resolution.json`  | the CLI that renders a project, instead of walking the tree itself                |
| `registrations.ts` | the host, to reach every mounted package and its lifecycle steps                  |
| `scribe.lock`      | the next resolution, and whoever asks why a package they never wrote down is here |

It is generated, and `.gitignore` keeps it out of the repository.

## Writing your own

`scribedev pkg create <name>` writes the layout every package has to have, and `scribedev pkg analyze <directory>` says
what is wrong with the ones already there. Neither is in this repository: `scribedev` is the command line the framework
is maintained with, and this is a library.
