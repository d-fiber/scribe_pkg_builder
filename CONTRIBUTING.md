# Contributing to the package builder

This is the library that reads the packages a framework checkout holds, settles their versions, and writes the four
files everything downstream obeys. It is imported, never typed: there is no command line here, and there is not going to
be one. `scribedev` is the command line the framework is maintained with, and a second executable that knew how to do
one more thing would only be one more place to look.

What you change here decides what a package is allowed to say about itself and what a project ends up able to import. A
wrong answer does not crash: it produces a map that grants too much, and nobody notices until a package reaches
something it was never meant to see.

## The licence, in one paragraph

This repository is under the Mozilla Public License 2.0. You may use it, change it, distribute it, and combine it with
files under any other licence, including a proprietary one. What you owe in return is per file: the source of every file
covered by these terms that you distribute, including the ones you changed, stays available under the same terms. The
full text is in `LICENSE`, and every file carries the notice.

By opening a pull request you are offering your change under those terms.

## Getting set up

You need Deno 2. This is developed against 2.7.

```sh
deno task check
deno task test
git config core.hooksPath .githooks
```

The hooks line is worth the five seconds: `pre-push` runs what CI runs, so a fault stays in your terminal instead of
turning up somewhere it blocks a release. `git push --no-verify` skips it when you know what you are doing.

There is nothing to build and nothing to install: this is a library, and the way you run what you just changed is the
example.

```sh
deno task example:test
```

Pin your Deno rather than letting it float. A release of Deno can change what type checks without a single commit on
your side, and finding that out in the middle of a change costs an afternoon.

## What this repository holds, and what it deliberately does not

One surface, `tools.ts`, and everything under `src/` reaches a project through it. It runs before anything is built,
never inside what it built, so it may read a directory, write a file and lean on `@std`.

What a package is written against is not here. The chain a package declares itself with, the three moments it runs at,
the values it passes around: that is the language, and it lives in
[`@scribe/alchemy`](https://github.com/d-fiber/scribe_alchemy), which a package reaches from anywhere on the machine.
This repository imports it like everybody else, and the registrations it writes import it too.

That is the line worth holding: a type a package needs goes to alchemy, and adding it here instead makes it a type only
somebody with the toolchain can name.

Writing a package and saying what is wrong with one are not here either. They are `scribedev pkg create` and
`scribedev pkg analyze`. The rules a person writes against live in the tool a person runs.

## Where your work goes

Everybody pushes to `dev`. There is no feature branch to make and no pull request to open, unless you are working from a
fork, in which case the pull request targets `dev` too.

`main` is the default branch, so that whoever lands on this repository sees what is published rather than what is being
written. That also means GitHub offers `main` as the base of a new pull request, and it is the wrong one: change it to
`dev`. Nothing reaches `main` except a promotion, and the section on versions below says how that works.

## Before you push

Read `STYLE.md` first. It says what the code has to look like to be read by somebody who did not write it, and it is
what your change is reviewed against. `TESTING.md` says what the proof has to look like.

CI runs four checks, and the `pre-push` hook runs the same four before your push leaves:

```
verify    tool/test.sh: it formats, lints, type checks, runs the suite and the example
headers   every source file carries the licence notice
commits   every message is tagged and under 72 characters
version   the version is a version, and whether it has moved since the last tag
```

`bash tool/test.sh` on its own covers the first of the four. The other three are why the hook is worth the five seconds
of setup: they fail for reasons the suite never sees.

`tool/test.sh` is what CI runs, not a convenience copy of it, so the two cannot drift:

```sh
deno fmt --check
deno lint
deno task check
deno test --allow-read --allow-write tests
deno task example:test
deno publish --dry-run --allow-dirty
```

That last one is the only tool here with an opinion about what you export. It refuses an exported function whose return
type it cannot read off the signature, so write the return type of everything you export, even where inference would
have got it right.

A file you add carries the licence notice, copied from the file next to it, before anything else in the file. That is
what `headers` refuses, and without the hook it refuses it after you pushed rather than before.

### Run what you wrote

Not the suite alone. The suite proves that a function answers what you expected; it does not prove that what the
function wrote is usable by whoever reads it. For everything under `src/emit/`, that second half is the whole of the
job.

```sh
deno task example

deno check --no-config --import-map examples/.scribe/imports.json examples/app/main.ts
deno check --no-config --import-map examples/.scribe/imports.json examples/.scribe/registrations.ts
deno test  --no-config --import-map examples/.scribe/imports.json examples/app examples/packages
```

Then prove the closure by breaking it. Take `audiences` out of realtime's `dependencies`, emit again, and check
`examples/packages/realtime/lib/src/channel.ts`. It has to answer
`Import "@scribe/audiences" not a dependency and not in import map`. A map that grants everything passes every assertion
you were going to write about it, so the refusal is the test that matters.

Put the manifest back afterwards.

### Write the test that would have caught it

A fault you found gets a test, written before the fix and failing without it. A rule, a refusal or a limit gets one too:
those paths are never walked by ordinary use, so nothing will report the day they stop working.

`TESTING.md` says when a test is owed, and how the two kinds of test here are reached.

## Adding to the library

The layout follows the subject, not the kind of file.

```
src/declaration/   what a package says about itself: the chain, the manifest, the names
src/version/       a version, a constraint, and the arithmetic between them
src/workspace/     the layout, the scope, the walk, and what is read off a tree
src/resolution/    the registry and the solver
src/emit/          emit, and the four files it writes
tests/<subject>.test.ts
```

Four things, and the last two are the ones people forget:

```
src/<subject>/<thing>.ts       the code, licence notice included
tests/<subject>.test.ts        the test, and see it red first
tools.ts                       the export, if a caller outside src/ needs it
.claude/scribe_pkg_builder/    the why, in the framework's own documentation
```

That last one is not optional and it is not a formality. The code carries the short reason on the declaration; the
decision and what it ruled out live in the documentation, and there is nowhere else for them to go. A choice whose
reason is written nowhere gets made again in six months, and nothing says it will be made the same way.

### An emitter comes in a pair

Everything under `src/emit/` that writes a file has a sibling that only builds the value. Keep the pair when you add
one: `importMapFor` and `writeImportMap`, `lockText` and `writeLock`, `registrationsSource` and `writeRegistrations`,
`resolutionDocument` and `writeResolution`.

It is not symmetry for its own sake. The first is testable without a temporary directory, and the second adds a `mkdir`
and a `writeTextFile` that nobody needs to assert on twice.

### Changing what a manifest holds touches another repository

`scribedev` keeps its own reader of `package.yaml`, in Dart, because it is a separate program in a separate language.
The four keys, `name`, `description`, `version` and `dependencies`, are a contract between the two repositories rather
than a local decision here.

If you change them, the change is two commits in this order: this repository first, then `scribe_dev_tools`. Anything
else leaves a window where one tool accepts a manifest the other refuses, with two different sentences for the same
fault.

## Commit messages

```
[TAG]: message
```

In English, imperative, no full stop, subject under 72 characters. The eleven tags: `DEV`, `BUGFIX`, `REFACTO`, `DOC`,
`TEST`, `CI`, `PERF`, `SECURITY`, `BREAKING`, `REVERT`, `CHORE`. A merge commit is taken as it is, since its message
starts with `Merge`.

A message names something you can go and check in the diff. It is read in six months by somebody looking for why a line
exists, and what they need is the fact, not what you thought of your work that afternoon.

```
No
[DEV]: various improvements
[DEV]: add comprehensive package resolution
[BUGFIX]: fix bug

Yes
[DEV]: grant a consumer what the workspace settled outside the framework
[BUGFIX]: stop the walk from entering a package it already found
[DOC]: say which half of the library a new module belongs on
```

If you cannot write the message in one line, the commit holds two things and wants splitting.

**One commit, one subject.** A working tree almost always holds unrelated things at once, and that is two commits rather
than one. It is what makes the history readable, `git revert` usable, and `git bisect` able to name a culprit.

```
No
[DEV]: add the emit chain and reformat the version module

Yes
[DEV]: add the emit chain
[REFACTO]: split the version module by subject
```

`BREAKING` wins over whatever else the change also is. It is the tag somebody scanning the history for what they have to
fix is looking for, and this library's public surface is what a whole framework compiles against.

## Versions, and how the framework picks them up

The version lives in `deno.json` and nowhere else.

You raise it. You do not write the changelog: when a push to `dev` carries a version that has moved, the CI reads every
commit since the last tag, groups them by their tag, writes the section, commits it, and only then names that commit
`v1.0.1`. What you write is the commit message; the section is made of them.

```
## 1.0.1

DEV:

- [DEV]: grant a consumer what the workspace settled outside the framework (a1b2c3d)

BUGFIX:

- [BUGFIX]: stop the walk from entering a package it already found (e4f5a6b)
```

The headings come in the order somebody reading it cares about: what breaks them, what they have to upgrade for, what
they gain, what stopped hurting, and the rest behind it. The commits that only raise the version or write the changelog
are left out, since they are the bookkeeping rather than the work.

The first version of all is the exception, and it is worth knowing before you write one. A first version has no tag
behind it, so everything counts as having moved and the CI writes its whole section from the commit list. Prose for a
first version therefore goes in after that push, never before.

`dev` can run three versions ahead of `main` and nothing is waiting on anybody.

`main` moves when the owner decides it moves, and nobody else. The `promote` workflow is run by hand and takes the
version being put out. It refuses anybody else who asks, it refuses a version `dev` does not hold, and it refuses a
version that was never tagged. Then it merges and writes the release from the changelog sections `main` had not yet
seen.

**Nothing is published to a registry.** This code lives in the framework's own repository under `host/pkg/builder/`, and
`host/deno.json` answers `@scribe/builder` with a path inside the checkout, the way it answers every other `@scribe/`
specifier it has. One repository, one version, one copy: whoever clones the framework gets the builder that framework
was tested against, and there is nothing to resolve and nothing to keep in step.

That is also why `deno publish --dry-run` stays in `tool/test.sh` even though nothing is ever published. It is the only
tool here with an opinion about the exported surface, and it is worth keeping for that alone.

Your work is done when it is on `dev` and the CI is green. What happens to it afterwards is not something you have to
wait for or ask about.

## Where the work stops

Some things are not yours to decide alone. Stop, and say what you found.

```
A secret in the diff              a token, a key, a .env, a long base64 in a config file
A generated file about to ship    examples/.scribe/ is ignored for a reason
A debugging leftover              a console.log in src/, a suite narrowed with a filter
A file written by tooling         deno.lock edited by hand rather than by deno
A change you cannot explain       a file you did not touch, modified, and you do not know why
```
