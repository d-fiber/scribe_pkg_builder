# Coding style

I wrote this for whoever opens a file here without having written it. Every rule below is followed by what it looks like
when you get it wrong and when you get it right, because a rule you have to interpret is a rule everybody interprets
differently.

Read it once before your first change. After that, the examples are enough.

---

## 1. Write like the file next to yours

The surrounding code decides the form. Naming, splitting, the way a fault is raised, the order of declarations. A better
answer that is foreign to the code it joins is still the wrong answer.

```ts
// No: nothing in this repository prints, and nothing ends the process. This is a library.
export async function loadDeclaration(directory: string) {
  if (!(await isFile(join(directory, MANIFEST_FILE)))) {
    console.error("not a package");
    Deno.exit(1);
  }
}

// Yes: the fault carries its sentence, and the caller decides what to do with it.
export async function loadDeclaration(directory: string): Promise<Declaration> {
  const path = join(directory, MANIFEST_FILE);
  if (!(await isFile(path))) {
    throw new DiscoveryError(`${directory} carries no ${MANIFEST_FILE}, so it is not a package.`);
  }
  ...
}
```

---

## 2. Name the thing, not its category

A name that could sit on anything names nothing.

```ts
// No
function process(data: Record<string, unknown>) { ... }
class ManifestHelper { ... }
class PackageUtils { ... }

// Yes
export function manifestFrom(source: string, where: string): Manifest { ... }
export function detectExports(directory: string, name: string): Promise<Map<string, string>> { ... }
```

---

## 3. A function does the work its name promises, and nothing else

If the honest name contains "and", there are two functions.

```ts
// No: whoever only wanted to read cannot say so, and the write happens anyway.
export function loadAndEmit(directory: string): Promise<void> { ... }

// Yes
export function loadDeclaration(directory: string): Promise<Declaration> { ... }
export function emit(asked: Emission): Promise<Resolution> { ... }
```

---

## 4. A side effect the name does not announce is a lie

A function that reads changes nothing. A function that builds a value writes no file.

```ts
// No: building the map also creates a directory. Call it twice to compare two maps and you get two.
export function importMapFor(packages: readonly DiscoveredPackage[], at: string): ImportMap {
  Deno.mkdirSync(dirname(at), { recursive: true });
  ...
}

// Yes: one builds, the other writes, and the test only needs the first.
export function importMapFor(...): ImportMap { ... }

export async function writeImportMap(...): Promise<void> {
  await Deno.mkdir(dirname(at), { recursive: true });
  await Deno.writeTextFile(at, `${JSON.stringify(importMapFor(packages, at, options), null, 2)}\n`);
}
```

Every emitter here comes in that pair: `importMapFor` and `writeImportMap`, `lockText` and `writeLock`,
`registrationsSource` and `writeRegistrations`, `resolutionDocument` and `writeResolution`. Keep the pair when you add
one.

---

## 5. One level of abstraction per function

The function that orchestrates calls named steps. It does not build a path between two of them.

```ts
// No: three named steps and one piece of plumbing at the same indentation.
export async function emit(asked: Emission): Promise<Resolution> {
  const packages = await discover(asked.roots);
  const resolution = resolve(asked.wants, new WorkspaceRegistry(packages));
  const kept = packages.filter((found) =>
    new Set(resolution.packages.map((entry) => entry.name)).has(found.declaration.name)
  );
  ...
}

// Yes: the plumbing has a name, and the body reads as a list of steps.
export async function emit(asked: Emission): Promise<Resolution> {
  const packages = await discover(asked.roots);
  const wants = asked.wants ?? everyOne(packages);
  const resolution = resolve(wants, new WorkspaceRegistry(packages));
  const mounted = kept(packages, resolution.packages.map((entry) => entry.name));
  ...
}
```

---

## 6. Past three parameters, a type is missing

And a boolean in a parameter list asks for two named functions.

```ts
// No: what does this call say? Nothing.
await emit(roots, out, wants, consumers, driver, imports, true);

// Yes: the type is the documentation, and every field of it is documented.
await emit({
  roots: [join(here, "packages")],
  into: join(here, ".scribe"),
  wants: new Map([["realtime", Constraint.any()]]),
  consumers: [join(here, "app")],
});
```

---

## 7. A class exposes what its name justifies

Read the name, then the list of members. A member that surprises belongs to another class.

```ts
// No: a version that knows how to reach a registry and how to print itself for a terminal.
export class Version {
  readonly major: number;
  readonly minor: number;

  fetchLatest(): Promise<Version> { ... }
  printTo(logger: Logger): void { ... }
}

// Yes: it holds three numbers and knows how to compare them, which is what a version is.
export class Version {
  readonly major: number;
  readonly minor: number;
  readonly patch: number;

  static parse(version: string): Version { ... }
  isAtLeast(other: Version): boolean { ... }
}
```

State closes by default. Use `#private` fields, not the `private` keyword: `#` is enforced at runtime, `private` is a
compile-time promise that anybody can cast away.

---

## 8. Make the wrong order impossible instead of checking for it

A value is valid as soon as it is built, not after three calls in the right order. TypeScript can hold that for you: a
step returns only what may legally follow it.

```ts
// No: nothing stops build() from running before a version was given, so build() has to check.
const manifest = new Package("realtime");
manifest.setVersion("1.2.0");
manifest.build();

// Yes: named() answers AwaitingDescription, so build() is not reachable until version() has run.
Package.named("realtime")
  .describedAs("Broadcasts a row to the callers a channel lets in.")
  .version("1.2.0")
  .dependsOn({ audiences: "^1.0.0" })
  .build();
```

The built value comes back frozen. A manifest that could be edited after the fact is a manifest two readers can disagree
about.

---

## 9. The third use moves into the shared place

Two uses, look. Three, share. There are two copies of `isDirectory` in this repository right now, in
`workspace/detect.ts` and `workspace/discovery.ts`. That is what two looks like. A third one moves.

And what moves loses its context: a shared function that needs a parameter to tell its callers apart is two functions,
not one.

```ts
// No: shared, then widened by one branch per caller.
function describe(thing: unknown, asPackage: boolean): string { ... }

// Yes
function describePackage(found: DiscoveredPackage): string { ... }
function describeResolved(resolved: ResolvedPackage): string { ... }
```

---

## 10. Nothing here prints, and nothing here exits

This is a library. `console.log`, `console.error` and `Deno.exit` do not appear anywhere under `src/`, and that is not
an accident: whoever imports this decides what a fault means and where a sentence goes. `examples/build.ts` prints,
because it is a program.

---

## 11. A fault a person can act on is a sentence, and it descends from `BuilderError`

Name what is wrong and say what to do about it. Everything raised on purpose here descends from `BuilderError`, so a
caller can tell a fault in what somebody wrote from a fault in this code, which keeps its stack trace.

```ts
// No
throw new Error("invalid name");

// Yes
throw new DeclarationError(
  `"${name}" cannot name a package. Use lowercase letters and single underscores, ` +
    `starting and ending with a letter, as in "dynamic_links".`,
);
```

One subclass per subject, and they are all one line: `ManifestError`, `DiscoveryError`, `DeclarationError`,
`VersionError`, `ResolutionError`, `EmissionError`.

---

## 12. Two stars, not one

This is the mistake that costs the most for the least reason. `/** */` is a documentation comment and the editor shows
it on hover. `/* */` above the same declaration is attached to nothing: the text is lost, and nothing warns you. One
character apart.

```ts
/* No: invisible on hover, invisible in the generated docs, and it looks right. */
export function entryOf(name: string): string { ... }

/** Yes: whoever types entryOf( sees this. */
export function entryOf(name: string): string { ... }
```

Use `/* */` only to switch code off while you try something, and never leave it in a commit.

---

## 13. Every export carries a `/** */`, and nothing here checks that it does

Dart has a lint that refuses an undocumented public member. Deno has no equivalent, so this one rests on you and on
whoever reads your diff. What is exported is the only surface a reader gets without opening the implementation, and
autocompletion shows them the signature and this comment and nothing else.

A one-sentence summary alone in its paragraph, and the tags after the prose.

```ts
/**
 * Every package under `roots`, sorted by name.
 *
 * @remarks
 * The walk stops at a package instead of entering it, because a package's own subdirectories carry
 * the same names it does.
 *
 * @throws {ManifestError} When a directory carries a manifest that cannot be read.
 */
export function discover(roots: readonly string[]): Promise<DiscoveredPackage[]> { ... }
```

Something internal is documented only when its name is not enough, and then it is usually the name that wants fixing.

---

## 14. Never write a type in a comment

TypeScript ignores `@type`, `@param {T}`, `@returns {T}`, `@template` and the rest: the language already has all of
them, and it checks them. A type written in a comment is a type nobody verifies. It ages without a word from anybody,
and `@param {string} name` above a `name: number` raises nothing at all.

```ts
// No: the signature already says all of this, and this copy can go stale.
/**
 * @param timeout {number} The timeout.
 * @returns {boolean} True or false.
 */

// Yes: what the signature cannot say.
/**
 * Waits for the socket to answer.
 *
 * @param timeout - Milliseconds before giving up. Must be positive.
 * @returns Whether the socket answered in time.
 */
```

The tags worth writing are `@remarks`, `@throws`, `@example`, `@defaultValue`, `@see`, `{@link}` and `@deprecated`,
which is the only one the compiler acts on. Give it a replacement or it is an opportunity wasted.

---

## 15. A function body carries no comment

What you were about to write in the middle goes up onto the declaration, where whoever calls it will see it.

```ts
// No: only whoever opens the implementation will ever read this.
export function importMapFor(...): ImportMap {
  // Only the entries a package exports are written, so lib/src/ stays private without
  // a rule that says it should.
  ...
}

// Yes: whoever calls it sees the constraint on hover.
/**
 * The map that lets each package reach what it declared, and lets nothing reach anything else.
 *
 * @remarks
 * Only the entries a package exports are written, so `@scribe/realtime/src/anything.ts` resolves
 * nowhere and the private half of a package stays private.
 */
export function importMapFor(...): ImportMap { ... }
```

The only `//` allowed inside a body is a directive a tool reads: `deno-lint-ignore`, `@ts-expect-error`. They are
instructions, not prose, and they have to stay glued to the line they aim at. Always give the reason, always take the
narrowest scope, and prefer `@ts-expect-error` to `@ts-ignore`: the first goes red the day the error disappears, so it
cleans itself up.

There is not one of them in this repository today. Adding the first one is worth a sentence in the commit message.

---

## 16. An exported interface documents every field, not the interesting ones

Two fields out of five documented reads as a claim that the other three have no unit, no range and no provenance. The
reader ends up distrusting all five.

```ts
// No
export interface DiscoveredPackage {
  readonly declaration: Declaration;
  readonly directory: string;

  /** The absolute path of the manifest the declaration was read from. */
  readonly manifest: string;
}

// Yes
export interface DiscoveredPackage {
  /** What the manifest declares, completed by what the tree holds. */
  readonly declaration: Declaration;

  /** The absolute path of the directory the package lives in. */
  readonly directory: string;

  /** The absolute path of the manifest the declaration was read from. */
  readonly manifest: string;
}
```

The first two lines teach almost nothing, and that is the point. They cost one line each and remove the doubt from the
third.

---

## 17. A comment says why, never what

The what is on the line below, and it will still be true when the comment has stopped being so.

```ts
// No
/** Increments the counter. */
function increment(): void { ... }

// Yes
/**
 * How many times this message has been delivered, starting at one.
 *
 * It is the server's count, not the payload's, so it cannot drift from what happened.
 */
readonly attempts: number;
```

---

## 18. A test file carries no comment

The name of the case and the assertion message are what show up when the suite goes red. A comment shows up nowhere.
`TESTING.md` takes this further.

---

## 19. Write the way you would say it out loud

Everything you write here gets read by somebody: a comment, a commit message, a test name, an assertion message,
whatever a program prints. Write it in sentences, with a subject and a verb, the way you would explain it to whoever is
sitting next to you.

What gives away text that was not written for a person is punctuation doing the job of a word. An arrow standing in for
"gives", a row of equals signs standing in for a heading, a slash standing in for "per".

```
No
0.412 ms/op -> 2427 ops/s
=== DONE! ===

Yes
0.412 ms per read, which is 2427 a second
2 packages written to .scribe
```

If you would not say it that way at a desk, do not write it in the source.

---

## 20. Say the real thing

The words that sell something say nothing about it. So do the phrases that describe a piece of code without naming
anything in it. Both survive forever, because there is nothing in them anybody could ever prove wrong.

```
No
Handles the edge case for robustness.
Does the work, for performance reasons.

Yes
The generated files are read by Deno on whatever machine holds them, and a backslash is a path
separator on one platform and an escape everywhere else, so a map generated on Windows would not
be readable by a container running Linux.
```

The test: somebody who knows nothing of the context understands it in one reading. If it takes two, the text is what has
to change, not the reader.

---

## 21. The source is in English

Whatever language the work is discussed in. Identifiers, comments, test names, assertion messages, and whatever a
program prints.

---

## What the tools hold you to

```sh
deno task check          # mod.ts, tools.ts, src, tests
deno task lint
deno task fmt
deno task test
deno task example:test   # writes examples/.scribe, then runs the example through it
```

`examples/` is deliberately out of `check`: its files resolve their imports only through the map `build.ts` writes,
which does not exist until it has run. `fmt` and `lint` do cover it, since neither resolves an import.

One more, and it is the only tool here that has an opinion about your public surface:

```sh
deno publish --dry-run --allow-dirty
```

It refuses an exported function whose return type it cannot read off the signature, with `missing-explicit-return-type`.
So write the return type of everything you export, even when inference would have got it right.

None of that judges whether the code is any good. That is what the twenty-one points above are for.
