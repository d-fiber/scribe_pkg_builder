#!/usr/bin/env bash
# Copyright (C) 2026 Fiber
#
# This Source Code Form is subject to the terms of the Mozilla Public License,
# v. 2.0. If a copy of the MPL was not distributed with this file, You can
# obtain one at https://mozilla.org/MPL/2.0/.
#
# What you may do:
# - Use this software for any purpose, including commercially, and build and
#   sell your own products on top of it.
# - Change it, and create new works based on it.
# - Distribute copies of it, with or without your changes.
# - Combine it with files under any other licence, proprietary ones included,
#   and licence that larger work on your own terms.
#
# What you must do in return:
# - Keep this notice on every file you received it on.
# - Publish, under these same terms, the source of every file covered by them
#   that you distribute, including the ones you changed, so that whoever
#   receives your version can obtain that source.
# - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
#   trademarks may not be used to endorse or promote what you build, and this
#   licence grants no right to them.
#
# Disclaimer:
# AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
# OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
# NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
# LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
# OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
# KIND OF LEGAL CLAIM.
#
# This header is a summary written for convenience. Where it differs from the
# LICENSE file, the LICENSE file governs.

set -euo pipefail

SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TARGET="${1:-}"
SCOPE="sync"

say() {
  echo "[$SCOPE] $1"
}

fail() {
  echo "[$SCOPE] $1" >&2
  exit 1
}

[ -n "$TARGET" ] || fail "Name the directory to copy into, as in .../scribe/host/pkg/builder"
[ -d "$(dirname "$TARGET")" ] || fail "$(dirname "$TARGET") does not exist, so $TARGET is not where you think"

mkdir -p "$TARGET"

rsync -a --delete \
  --exclude '/.git' \
  --exclude '/.github' \
  --exclude '/.githooks' \
  --exclude '/.gitignore' \
  --exclude '/tool' \
  --exclude '/examples' \
  --exclude '/deno.json' \
  --exclude '/deno.lock' \
  --exclude '/LICENSE' \
  --exclude '/README.md' \
  --exclude '/CONTRIBUTING.md' \
  --exclude '/STYLE.md' \
  --exclude '/TESTING.md' \
  --exclude '/CHANGELOG.md' \
  "$SOURCE/" "$TARGET/"

python3 - "$SOURCE/deno.json" "$TARGET/deno.json" <<'PYTHON'
import json
import sys

source, target = sys.argv[1], sys.argv[2]
held = json.load(open(source))
open(target, "w").write(json.dumps({"name": held["name"], "exports": held["exports"]}, indent=2) + "\n")
PYTHON

say "copied $(find "$TARGET" -type f | wc -l | tr -d ' ') files into $TARGET"
say "wrote its deno.json from name and exports, without the tasks or the imports"
