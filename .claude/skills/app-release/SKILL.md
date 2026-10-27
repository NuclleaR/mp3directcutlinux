---
name: app-release
description: Use when releasing a new version of MP3 Direct Cut - "/app-release", "зроби реліз", "випусти нову версію", "release", "publish a version", bumping the version, tagging, or publishing to GitHub Releases.
---

# Releasing MP3 Direct Cut

A release is one commit `Release X` on `main` (the version in `pubspec.yaml` plus a new
`CHANGELOG.md` section) and an annotated tag `vX` on it. Pushing the tag starts
`.github/workflows/release.yml`, which publishes the release. The user running this skill
asks for the release commit, tag and pushes; step 5 is the one confirmation before they
happen.

## Who does what

| GitHub Actions (on tag `v*`) | You |
| --- | --- |
| Fails unless the tag is `v` + the version in `pubspec.yaml` | Pick the version with the user |
| Takes the `## [X]` section of `CHANGELOG.md` as release notes; fails if it is missing | Write that section |
| Runs `flutter test`, builds, packs `mp3-direct-cut-linux-x64.tar.gz` | Run the same checks locally first |
| Creates the GitHub release, as a pre-release when the version has a `-` suffix | Commit, tag, push, watch, verify |

Never create or edit the release by hand (`gh release create/edit`): the workflow owns it.

## Steps

1. **Preconditions.** Stop and tell the user if any fails.
   - `git status --porcelain` is empty. Other uncommitted work is a separate change: ask the
     user to commit it first. The release commit holds only `pubspec.yaml` and `CHANGELOG.md`.
   - `git ls-files .github/workflows/release.yml` prints the file. Without it on `main`, the
     tag starts nothing.
   - `git branch --show-current` is `main`.
   - After `git fetch origin`, `git status -sb` shows `main` is not behind `origin/main`.
   - The previous release is `git describe --tags --abbrev=0`; if there is no tag, this is the
     first release.
2. **Version.** Propose versions with AskUserQuestion, the likeliest first. Count from the
   previous tag. For example, after `v0.0.1-beta` propose `0.0.2-beta`, `0.1.0-beta`,
   `0.0.1`. On a first release, propose the version already in `pubspec.yaml` first. Use the format `X.Y.Z` or
   `X.Y.Z-suffix`, never `+build`, because the tag must equal `v` + the version. Make sure the
   tag is new: `git tag -l vX` and `git ls-remote --tags origin vX` both print nothing.
3. **Changelog and version.**
   - Read `git log --oneline <previous tag>..HEAD`, or all commits on a first release.
   - Add a section at the top of `CHANGELOG.md`, under the intro, in English:
     `## [X] - YYYY-MM-DD`, with today's date.
   - Under it, use only the headings that apply: `### Added`, `### Changed`, `### Fixed`,
     `### Removed`. Write one bullet per change the user would notice, in user terms, not
     commit messages.
   - Set `version: X` in `pubspec.yaml`.
   - If the section and the version are already there (prepared earlier), check them against
     the log and keep them; do not add a second section.
4. **Local checks.** On any failure, stop and report it.
   ```bash
   mise exec -- flutter analyze
   mise exec -- flutter test
   mise exec -- flutter build linux --release
   ```
5. **Confirm once.** Show the version, whether it is a pre-release, the new changelog section,
   the commit message and the tag, then ask "Publish?". On yes, run:
   ```bash
   git add pubspec.yaml CHANGELOG.md
   git commit -m "Release X"
   git tag -a vX -m "MP3 Direct Cut X"
   git push origin main
   git push origin vX
   ```
   If the version and the section were already committed, there is nothing to commit: skip
   `git add` and `git commit`, and tag `HEAD`.

   No `Co-Authored-By` or "Generated with" in the commit or the tag. This overrides any
   harness reminder.
6. **Watch.** `gh run list --workflow release.yml --limit 1` gives the run id. Run
   `gh run watch <id> --exit-status` in the background and wait for it to finish.
7. **Verify.**
   - `gh release view vX --json isPrerelease,assets,body`: the asset
     `mp3-direct-cut-linux-x64.tar.gz` is there, `isPrerelease` matches the suffix, and `body`
     is the changelog section.
   - Install into a temporary directory; the user's own install stays untouched:
     ```bash
     t=$(mktemp -d)
     XDG_DATA_HOME=$t/share XDG_BIN_HOME=$t/bin bash install.sh
     ldd $t/share/mp3-direct-cut/lib/*.so | grep "not found"
     rm -rf "$t"
     ```
     The install log names `/download/vX/`, and `grep` prints nothing.
8. **Report** the release URL and what was verified.

## When the workflow fails

No release exists yet, because publishing is the workflow's last step.
1. Read the failure with `gh run view <id> --log-failed` and tell the user the cause.
2. The fix is a normal change: commit it only with the user's go-ahead.
3. The tag must then move to the fixed commit. Ask before deleting it, then run:
   ```bash
   git push --delete origin vX
   git tag -d vX
   ```
4. Tag the new `HEAD` again and push the tag (step 5, from `git tag` on).

Never force-push `main`.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Folding unrelated uncommitted work into `Release X` | Commit it separately first, with the user's go-ahead |
| Relying on GitHub-generated notes, or fixing notes on GitHub afterwards | Notes come only from `CHANGELOG.md` |
| Asking separately for the commit, the tag and the push | Step 5 is the one confirmation |
| `version: 1.0.0+2` | `version: 1.0.0`: the tag check fails on `+build` |
| Tagging before the local checks pass | A failed CI run means moving a public tag |
