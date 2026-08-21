# @scribe/builder

The package toolchain of the [scribe](https://github.com/d-fiber/scribe) framework.

It reads the packages a framework checkout holds, settles which version of each one a project ends up with, and writes
the four files everything downstream obeys. It is a library: you import it, and there is nothing here to install and no
command to type.

## Where it sits

Three programs work on packages, and each has one job.

|                         | What it does                                                                              |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| `scribedev pkg create`  | writes a package, laid out the way every package has to be                                |
| `scribedev pkg analyze` | reads the packages under a directory and says what is wrong with them                     |
| `@scribe/builder`       | reads the packages that already exist, resolves them, and writes what the toolchain obeys |

The rules a person writes against live in the tool a person runs, which is
[`scribedev`](https://github.com/d-fiber/scribe_dev_tools). What is here runs on their behalf, before anything is built,
and an author of a package never types its name.

## Getting it

A framework checkout carries it under `host/pkg/builder/`, and nothing outside the toolchain reaches it. It is not
published, and it does not need to be: it never runs inside a project.

```ts
import { emit } from "@scribe/builder/tools";
```

## What it is not

It used to carry a second half, the chain a package declares itself with and the three moments it runs at. That half is
the language every package is written against, so it lives in
[`@scribe/alchemy`](https://github.com/d-fiber/scribe_alchemy) now, published on its own and reachable from anywhere.

What is left here is the toolchain: reading a tree, settling versions, and writing the four files. The registrations it
writes import `@scribe/alchemy`, never this.

## What a package is

A directory carrying a `package.yaml`, and nothing else says so.

```yaml
name: realtime
description: Broadcasts a row to the callers a channel lets in.
version: 1.2.0

dependencies:
  audiences: "^1.0.0"
```

Four keys, and no others. Everything else about a package is read off its tree rather than written down twice: where its
entry is, what it exports, what SQL it poses, what it imports from outside the framework. A path that has to be declared
as well as laid out is a chance for the two to disagree, and the one that loses is always the tree, since that is what
actually runs.

## What the map grants, and what it closes

A package reaches the packages it declared, and whatever it writes outside the framework that the workspace has settled.
A project reaches what it named, and not what came in behind it.

Two things are closed there rather than by a rule somebody has to run. Only the entries a package exports are written,
so `@scribe/realtime/src/anything.ts` resolves nowhere and the private half of a package stays private. And every grant
sits in the scope of the directory that declared it, so a package pulled in behind another is on disk, is mounted, and
is unreachable from code that did not ask for it.

Both failures read as Deno's own `not a dependency and not in import map`.

## Seeing it work

`examples/` is a workspace of two packages and a project that mounts one of them, plus the twenty lines that call
`emit`. It runs, which is the point of it.

```sh
deno task example        writes .scribe/ and says what it settled on
deno task example:test   writes it, then runs every test through the map it wrote
```

`examples/README.md` says what each piece of it is there to show.

## Working on it

`CONTRIBUTING.md` says how a change is made and what it has to pass before it is opened. `STYLE.md` says what the code
has to look like, which is what a review is done against. `TESTING.md` says what the proof has to look like.
`CHANGELOG.md` says what each version holds.

## Layout

```
tools.ts             the one way in
src/declaration/     the manifest on disk: reading it, writing it, and what a walk found beside it
src/workspace/       the layout, the scope, the walk, and what is read off a tree
src/resolution/      the registry and the solver
src/emit/            emit, and the four files it writes
examples/            a workspace that runs, and what the builder makes of it
```

Everything under `src/emit/` that writes a file has a sibling that only builds the value, so the half worth asserting on
is testable without a disk.

## Licence

Mozilla Public License 2.0. The terms are in `LICENSE`, and each file carries the notice.
