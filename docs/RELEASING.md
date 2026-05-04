# Releasing

## Release notes source
- GitHub Release notes come from `CHANGELOG.md` for the matching version section (`## X.Y.Z - YYYY-MM-DD`).

## Steps
1. Update changelog and version
   - Ensure `CHANGELOG.md` has `## 0.2.0 - YYYY-MM-DD` with final notes.
   - Update `version.env` to `0.2.0`.
   - Run `scripts/generate-version.sh` (refreshes `Sources/remindctl/Version.swift` + embedded Info.plist).
2. Ensure checks are green
   - `make check`
3. Build, sign, and notarize (local)
   - Requires `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`.
   - `scripts/sign-and-notarize.sh` (outputs `/tmp/remindctl-macos.zip` by default).
4. Tag, push, and publish
   - `git tag -a v0.2.0 -m "v0.2.0"`
   - `git push origin v0.2.0`
   - Extract release notes:
     ```sh
     version=0.2.0
     notes_file=/tmp/release-notes.txt
     awk -v v="$version" '
       $0 ~ ("^## " v "($|[[:space:]]-)") { in_section=1; next }
       in_section && $0 ~ "^## " { exit }
       in_section { print }
     ' CHANGELOG.md > "$notes_file"
     ```
   - Create GitHub release:
     ```sh
     gh release create v0.2.0 /tmp/remindctl-macos.zip -t "v0.2.0" -F /tmp/release-notes.txt
     ```
5. Update Homebrew tap
   - Run `scripts/update-homebrew.sh vX.Y.Z` to trigger and watch the centralized formula updater.
   - Requires a GitHub token with workflow dispatch access to `steipete/homebrew-tap`.

## What happens in CI
- Release signing + notarization are done locally via `scripts/sign-and-notarize.sh`.
- `.github/workflows/release.yml` is only for manual rebuilds, not the primary release path.
