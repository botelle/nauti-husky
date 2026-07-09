# Contributing — CI, branching & the Xcode project

## Branch & merge policy
`main` is protected. All changes land via pull request — no direct pushes to `main`.

A PR may merge only when:
- its CI check is **green** (`App Tests / test (pull_request)`), and
- the branch is **up to date with `main`** (Forgejo blocks merging an outdated branch).

Updating an outdated branch (the **Update Branch** button, or merging `main` in) re-runs CI,
so the suite runs against the post-merge tree **before** landing. `main` is also re-tested on
every push as a backstop. Forgejo has no serialized merge queue; "required check +
block-on-outdated + **Auto Merge**" is the practical equivalent.

## The Xcode project is generated — don't commit it
The `.xcodeproj` is produced by **XcodeGen** from `project.yml`. Committing the generated
`project.pbxproj` makes it a merge-conflict magnet. Therefore:
- `project.yml` is the source of truth and is committed.
- The generated `*.xcodeproj` is git-ignored and regenerated: locally `xcodegen generate`
  after cloning; in CI the workflow already runs `xcodegen generate` before building.
- A fresh clone has no `.xcodeproj` until you run `xcodegen generate`.
