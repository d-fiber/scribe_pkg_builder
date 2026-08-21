# Tests

Writing is not finishing. A change is done when it has run, not when it looks right, and "it should work" is a
hypothesis rather than a state.

`STYLE.md` says what the code has to look like. This says what the proof has to look like.

---

## 1. Running is not reading

Rereading your own diff proves nothing: you reread what you meant to write. Go through the real way in, with real input.

```sh
deno task test
deno task example:test
```

The case that is meant to be refused counts as much as the case that is meant to pass. That is where new code breaks,
never on the example you had in mind while writing it. A manifest with no version, a root that does not exist, a
constraint no published version answers, two packages that need each other.

---

## 2. The proof of a generator is what reads what it generated

This is the one rule here that belongs to this repository rather than to testing in general. Everything under
`src/emit/` writes a file for somebody else to read, and asserting on the text of that file only proves that you wrote
down what you expected to write down. The proof is handing it to its reader.

```sh
deno task example

# The map is right when Deno resolves through it.
deno check --no-config --import-map examples/.scribe/imports.json examples/app/main.ts
deno test  --no-config --import-map examples/.scribe/imports.json examples/app examples/packages

# The registrations are right when they type check.
deno check --no-config --import-map examples/.scribe/imports.json examples/.scribe/registrations.ts
```

And the closure is proved by what stops resolving. Take `audiences` out of realtime's `dependencies`, emit again, and
`lib/src/channel.ts` answers `Import "@scribe/audiences" not a dependency and not in import map`. A map that grants
everything passes every assertion you were going to write about it.

---

## 3. A test is written when its absence would let the problem come back

Not every change needs one, and pretending otherwise makes the suite noise.

```
It needs one
A fault you found                      it comes back otherwise, and nothing will say so
A rule, a refusal, a limit             ordinary use never walks that path
A function with branches               many cases for very little setup
A behaviour you have just decided      so that nobody undoes the decision by accident

It does not
A rename the compiler checks entirely
A change of wording
A move with no change of behaviour
A tweak to a task in deno.json
```

When you are unsure, the question is who will tell you if this breaks in six months. When the answer is nobody, write
the test.

---

## 4. Two kinds of test live here, and they are reached differently

The rules are pure and are called straight: a version, a constraint, the solver, the chain, a manifest read from a
string. No disk, no fixture, and a case per line.

```ts
Deno.test("a manifest with no name is refused", () => {
  assertThrows(() => manifestFrom("version: 1.0.0\n", WHERE), ManifestError, 'has no "name:"');
});
```

Everything that reads or writes a tree goes through a temporary root and the harness, so what is under test is the walk
and not the fixture.

```ts
Deno.test("discovery does not enter a package it has found", async () => {
  await inTemporaryRoot(async (root) => {
    const realtime = await writePackage(root, "realtime");
    await writePackage(join(realtime, "tests"), "audiences");

    const found = await discover([root]);
    assertEquals(
      found.map((entry) => entry.declaration.name),
      ["realtime"],
      "the walk went inside a package",
    );
  });
});
```

When both are available, take the pure one. `importMapFor` and `writeImportMap` exist as a pair for exactly this reason:
the first is testable without a disk, and the second adds a `mkdir` and a `writeTextFile` that nobody needs to assert on
twice.

---

## 5. Anything that touches the disk gets a directory of its own

A temporary one, removed whether the case passed or not. That is what `inTemporaryRoot` is: the `finally` is the whole
point of it existing.

```ts
export async function inTemporaryRoot(body: (root: string) => Promise<void>): Promise<void> {
  const root = await Deno.makeTempDir({ prefix: "scribe_builder_" });
  try {
    await body(root);
  } finally {
    await Deno.remove(root, { recursive: true });
  }
}
```

Never a path inside the repository, and never a path two cases share. Deno runs test files in parallel, so a shared
directory is a suite that fails on somebody else's machine and passes on yours.

---

## 6. Build the fixture with the harness, not by hand

A fixture written by hand drifts from what a package actually looks like, and then the tests pass while the code is
wrong.

```ts
// No: the day a package gains something, this fixture keeps passing and means nothing.
await Deno.mkdir(join(root, "audiences", "lib"), { recursive: true });
await Deno.writeTextFile(join(root, "audiences", "package.yaml"), "name: audiences\n");

// Yes
await writePackage(root, "realtime", {
  version: "1.2.0",
  dependencies: { audiences: "^1.0.0" },
  files: { "lib/realtime.ts": 'import { mounted } from "@scribe/audiences";\n' },
});
```

`tests/support/workspace.ts` writes the manifest and the entry and nothing else, on purpose: what a package must carry
beyond those is `scribedev pkg analyze`'s to say, not this repository's. A fixture here is a package these tools can
read, not one that would pass that check.

The harness is imported by other files, which makes it code like any other: its surface is documented, even though the
test files that use it carry no comment at all.

---

## 7. A test you have never seen fail proves nothing

See it red before you see it green. A test written after the fix, passing first time, has demonstrated nothing and may
be checking nothing at all.

It also tends to describe what the code does rather than what it should do, bug included, because you copied the output
into the expectation. Decide the expected value before looking at the result.

---

## 8. When a test goes red, the code is wrong until proven otherwise

Adjusting the expectation removes the only warning you had.

```ts
// No: the map now grants three things, so the test was made to accept three.
assertEquals(Object.keys(map.scopes["../app/"]).length, 3);

// Yes: name the three, and find out whether the third should be there.
assertEquals(
  map.scopes["../app/"],
  {
    "@scribe/realtime": "../packages/realtime/lib/realtime.ts",
    "@scribe/realtime/testing": "../packages/realtime/tests/testing/realtime.ts",
    "@std/assert": "jsr:@std/assert@1",
  },
  "the project's own code reaches something it never named",
);
```

---

## 9. The name of the case and the assertion message are the whole documentation

They are what shows up when the suite is red. A comment shows up nowhere, so a test file carries none.

```ts
// No
Deno.test("emit", async () => {
  // a package pulled in behind another should not be direct
  ...
  assertEquals(document.packages[0].direct, false);
});

// Yes
Deno.test("a package pulled in behind another lands in the resolution as transitive", async () => {
  ...
  assertEquals(document.packages[0].direct, false, "audiences came back direct");
});
```

The name says the case and what is expected of it. The message says what distinguishes this assertion from the others in
the same case. Every `assertEquals` here takes one, and the ones that do not are the ones worth fixing first.

---

## 10. Assert on the part of the sentence that carries the meaning

Otherwise every reword turns the suite red for nothing, and teaches nobody anything when it does.

```ts
// No: the day somebody improves the wording, this fails and the failure explains nothing.
assertThrows(
  () => Package.named("Realtime"),
  DeclarationError,
  '"Realtime" cannot name a package. Use lowercase letters and single underscores, ' +
    'starting and ending with a letter, as in "dynamic_links".',
);

// Yes
assertThrows(() => Package.named("Realtime"), DeclarationError, "cannot name a package");
```

The class matters as much as the text. `assertThrows(fn, DeclarationError, ...)` also proves the fault descends from
`BuilderError`, which is what tells a caller it is a fault in what somebody wrote rather than a fault in this code.

For anything asynchronous, `assertRejects`, and never a bare `await` in a `try` you forgot to finish. A rejection nobody
awaited passes.

---

## 11. Never freeze a number somebody else moves

A version literal in a test goes red at the first release, and the release is automatic. Compare against the constant
that holds it.

```ts
// No
assertEquals(
  chainOf(manifest),
  'Package.named("audiences").describedAs("Say in one sentence what this package does.")…',
);

// Yes
assertEquals(
  chainOf(manifestFrom("name: audiences\nversion: 1.0.0\n", WHERE)),
  `Package.named("audiences").describedAs(${JSON.stringify(DEFAULT_DESCRIPTION)}).version("1.0.0").build()`,
  "the chain says more than the manifest did",
);
```

---

## 12. Setup that needs explaining wants a name

```ts
// No
const d = join(root, "realtime"); // the one the fixture wrote above

// Yes
const realtime = await writePackage(root, "realtime");
```

A helper shared by the cases of one file lives at the top of that file, like `chain` and `settled` in
`tests/emit.test.ts`. A helper shared by several files lives in `tests/support/`.

---

## 13. Take away what you made to test

Directories, sample workspaces, files dropped somewhere to see how the code reacts. Left behind, they become a state
somebody will eventually take for real. `examples/.scribe/` is the exception, and only because `.gitignore` keeps it
out.

Delete by looking at what you delete. List first, name what goes, and never delete a pattern.

---

## 14. Say what you ran, and say what you did not

A verification you announce without having done it is worse than one you skipped, because it hands over confidence that
rests on nothing.

```
No
Tested, everything passes.

Yes
deno task test is green, 70 cases. deno task example:test writes the four files and runs the
five example tests through the map it wrote. I did not run this on Windows, so the forward
slashes specifierFrom normalises are unverified there.
```

When something fails, report it with the real output. A failure described from memory loses exactly the detail that
would have explained it.

---

## What runs it

```sh
deno task test                         # the suite
deno task test --filter "import map"   # the same, narrowed to the cases whose name matches
deno test --allow-read --allow-write tests/emit.test.ts

deno task check                        # types, everything but examples/
deno task lint
deno task fmt
deno task example:test                 # the example, through the map it just wrote
deno publish --dry-run --allow-dirty   # what the published surface has to satisfy
```

Green on all of them is the floor, not the finish. What the suite cannot tell you is whether the thing was worth writing
that way, and `STYLE.md` is where that gets decided.
