---
name: release
description: Cut a PingMate release — tag, watch the build, publish the DMG and bump the Homebrew cask. Use when asked to release, ship, cut a version, or publish a new PingMate build.
---

# Releasing PingMate

A release is a tag push. Everything else follows from it, except the cask, which is updated by hand
in a second repository.

**Never push to `main` directly — in either repo.** Every change, including a one-line cask bump,
goes on a branch and through a pull request. Tags are the only thing pushed straight to the remote,
and only after the PR they build on has been merged.

- App repo: `kikudjira/pingmate` (this one)
- Tap repo: `kikudjira/homebrew-pingmate`, working copy at `/Users/kikudjira/github/homebrew-pingmate`

There is nothing to bump in the source. `MARKETING_VERSION` is injected from the tag name and
`CURRENT_PROJECT_VERSION` from the run number, so the only place a version is decided is the tag.

## 1. Land the changes through a PR

Whatever is going into the release lives on a branch:

```sh
git checkout -b <branch>
git commit ...
git push -u origin <branch>
gh pr create --base main --title "..." --body "..."
```

Hand the diff over for review before opening the PR, and let the author merge it. Only then tag.

## 2. Preflight

```sh
git checkout main && git pull
git status --porcelain                     # must be empty
git log --oneline origin/main..HEAD        # must be empty — the tag builds what is on the remote
```

Build once locally before tagging anything. A red CI run on a tag is annoying to undo, because the
tag has to be deleted from the remote before it can be reused:

```sh
./scripts/build-app.sh <version> 0
./scripts/make-dmg.sh <version>
```

Confirm the app still launches and pings, and remember to `pkill -x PingMate` before running a
local build — the copy from `/Applications` is usually already in the menu bar and they share a
`UserDefaults` domain.

## 3. Tag

Semver, `v` prefix. Patch for fixes, minor for features.

```sh
git tag -a v<version> -m "PingMate <version>"
git push origin v<version>
```

## 4. Watch the run

```sh
gh run list -R kikudjira/pingmate --limit 1
gh run watch <run-id> -R kikudjira/pingmate --exit-status --interval 20
```

Takes about 70 seconds. It builds a universal, ad-hoc signed app on `macos-26`, packages a DMG,
publishes the release with generated notes, and prints the cask lines into the run summary.

If the run fails, fix forward and re-tag:

```sh
git tag -d v<version> && git push origin :refs/tags/v<version>
```

## 5. Bump the cask by hand

The workflow cannot push to the tap — `GITHUB_TOKEN` is scoped to this repo — so it only prints
what changed. **Never copy the sha256 from a local build**: CI produces its own DMG and the hash
will differ. Take it from the released asset.

```sh
cd /tmp && gh release download v<version> -R kikudjira/pingmate -p "*.dmg"
shasum -a 256 PingMate-<version>.dmg
```

Then in `/Users/kikudjira/github/homebrew-pingmate/Casks/pingmate.rb` update the two lines:

```ruby
  version "<version>"
  sha256 "<hash from the released DMG>"
```

The tap gets the same treatment as the app repo — branch, PR, merge. A one-line bump is still a
pull request:

```sh
cd /Users/kikudjira/github/homebrew-pingmate
brew style Casks/pingmate.rb        # must be clean
git checkout -b cask-<version>
git commit -am "chore: cask -> <version>"
git push -u origin cask-<version>
gh pr create --base main --title "chore: cask -> <version>" --body "..."
```

Until that PR is merged, `brew install` still serves the previous version.

## 6. Verify the published artefact

```sh
brew fetch --cask kikudjira/pingmate/pingmate   # checksum must match
```

For a real end-to-end check, reset the local state first — otherwise the tap is already trusted and
the install proves nothing about a first-time user:

```sh
brew untap kikudjira/pingmate
# drop only the "kikudjira/pingmate/pingmate" entry from ~/.homebrew/trust.json
brew install --cask kikudjira/pingmate/pingmate
xattr -p com.apple.quarantine /Applications/PingMate.app   # must report "No such xattr"
```

## Things that will bite

- **The install must use the fully-qualified name.** `brew install --cask kikudjira/pingmate/pingmate`
  auto-taps and is auto-trusted because the full name is in the arguments. `brew install --cask pingmate`
  after a plain `brew tap` fails with `Refusing to load cask ... from untrusted tap`.
- **`macos-26` is required**, not a preference. The UI uses Liquid Glass APIs from the macOS 26 SDK.
- **The build is ad-hoc signed, not notarized.** The cask strips the quarantine attribute in
  postflight. Anyone installing the DMG by hand needs `xattr -dr com.apple.quarantine`.
- **Two PingMate copies coexist** during development: `/Applications` and `build/`. They share
  settings. Kill one before judging the behaviour of the other.
- **Release notes are generated** from commits since the previous tag, so commit subjects are the
  changelog. Write them accordingly.
