# Releasing

## Release notes source
- GitHub Release notes come from `CHANGELOG.md` for the matching version section (`## X.Y.Z - YYYY-MM-DD`).

## Steps
1. Update changelog and version
   - Ensure `CHANGELOG.md` has `## X.Y.Z - YYYY-MM-DD` with final notes.
   - Update `version.env` to `X.Y.Z`.
   - Run `scripts/generate-version.sh` (refreshes `Sources/remindctl/Version.swift` + embedded Info.plist).
2. Ensure checks are green
   - `make check` (strict lint, tests, and the 90% coverage gate)
   - `make macos-artifact` (builds `dist/remindctl-macos.zip` and verifies it contains arm64 + x86_64 slices)
   - `make release-check TAG=vX.Y.Z`
3. Commit and tag
   - `git tag -a vX.Y.Z -m "vX.Y.Z"`
   - `git push origin vX.Y.Z`
4. Autorelease
   - Pushing `v*` tags runs `.github/workflows/release.yml`.
   - The workflow builds a universal `remindctl-macos.zip`, verifies the archive contains arm64 + x86_64 slices, creates or updates the GitHub Release, replaces release notes from the matching `CHANGELOG.md` section, then dispatches the Homebrew tap formula updater.
   - Requires `HOMEBREW_TAP_TOKEN` with workflow dispatch access to `steipete/homebrew-tap`.

## Manual rerun
- Use the `release` workflow dispatch with `tag=vX.Y.Z` to rebuild an existing tag.
- Use `scripts/update-homebrew.sh vX.Y.Z` to rerun only the centralized formula updater.

## What happens in CI
- `.github/workflows/release.yml` runs on pushed `v*` tags and manual dispatch.
- The GitHub-hosted artifact is a universal macOS binary and is ad-hoc signed for Homebrew distribution.
- `scripts/sign-and-notarize.sh` remains available for local notarized builds when needed.
