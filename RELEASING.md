# Releasing Nudgy

## Automatic draft releases

Merging a PR into `main` runs **Draft Next Release**, which creates or updates one
unpublished GitHub release with the merged PR titles and contributors. Direct
pushes to `main` also refresh the draft. Later merges accumulate in the same
draft until that version is published.

The draft contains release notes only. It does not change `VERSION`, create a
published app version, or build a DMG. The workflow can also be run manually from
the repository's **Actions** page with the `main` branch selected.

The next version is calculated from the last published release:

| PR label | Version increment |
| --- | --- |
| `breaking-change` | Major |
| `enhancement` or `feature` | Minor |
| Any other label, or no label | Patch |
| `skip-changelog` | Omit the PR from the release notes |

The largest requested increment wins. Create optional labels such as
`breaking-change` and `skip-changelog` in the repository when needed. Apply labels
before merging; after changing a label on an already merged PR, run **Draft Next
Release** manually to refresh the draft.

## Publish a Nudgy version

1. Review the draft release notes and choose the version to ship.
2. Set both root `VERSION` and `Info.plist`'s `CFBundleShortVersionString` to that
   version, without the `v` prefix.
3. Merge the version-bump PR into `main` after CI passes. The existing **Auto Tag &
   Release** workflow creates the `v<version>` tag, runs tests, builds, signs and
   notarizes the app, then attaches the DMG and publishes the release.
4. Verify the workflow succeeded and the release has `Nudgy-<version>.dmg` attached.

Do not publish the notes-only draft from GitHub's UI as a substitute for the
version-bump workflow: that alone does not ensure a correctly versioned app and
signed DMG. Do not push a second tag for the same version while automation is
running. If a release job fails, inspect its logs before retrying; do not move or
delete an existing published tag to retry a release.

The signing and notarization secrets used by the existing publishing workflow
are not needed for draft creation. Drafting uses only GitHub's built-in token,
with `contents: write` (needed to manage releases) and `pull-requests: read`
permissions, and does not check out or execute contributor code.

All three release-writing workflows share a concurrency queue so a draft update
cannot race with publication. If publication finishes before a queued draft
update, that update may prepare an empty draft for the following version.

## Reuse in another repository

1. Copy `.github/workflows/release-drafter.yml` and
   `.github/release-drafter.yml` into that repository.
2. Change the workflow's `main` branch filter and job condition if its default
   branch differs.
3. Adjust the configuration's labels and version/tag templates to that project's
   conventions. The provided setup assumes semantic versions such as `v1.2.3`.
4. Merge a small PR and verify **Draft Next Release** creates a draft on the
   **Releases** page. No personal access token or signing secrets are required.

If another workflow also writes GitHub releases, give it the same concurrency
group, `queue: max`, and `cancel-in-progress: false` settings to serialize those
writes. These queue settings are supported on GitHub.com; check support before
copying them to an older GitHub Enterprise Server instance.

This copies only the draft-release system. Keep each repository's own tested
build and publishing process for attaching artifacts and shipping a version.
