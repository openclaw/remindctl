# Releasing

Official releases are built, Developer ID-signed, and notarized on an authorized local Mac. GitHub Actions only verifies an existing draft or published release. It cannot package, sign, notarize, publish, or mutate Homebrew.

## Fixed identity and inventory

- Repository: `openclaw/remindctl`
- Homebrew route: `steipete/tap/remindctl`
- Code identifier: `com.steipete.remindctl`
- Developer ID: `Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)`
- Architectures: `arm64 x86_64`
- Assets: `remindctl-macos.zip`, `checksums.txt`, and `release-inventory.json`

The inventory binds the archive to the exact protected-default-branch commit and exact annotated signed-tag object. The tag must peel to that commit both locally and on the live remote. Official packaging captures this proof before building and rechecks it after notarization so a moved branch or tag leaves no partial release output.

The universal binary is assembled first, then signed once with the hardened runtime and a secure timestamp. The notary profile and release keychain credential locator are supplied only at runtime through the approved release handoff. Use `.mac-release.env.example` for non-secret configuration; runtime keychain and credential locations must never be committed.

Apple creates an online ticket for a notarized standalone executable but does not support stapling that ticket to the executable. The native verifier therefore runs `codesign --verify --strict --check-notarization -R=notarized` for each architecture in addition to checking each slice's exact Foundation metadata, embedded designated requirement, hardened runtime, secure timestamp, and embedded Info.plist identifier/version. See [Apple's custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow#Staple-the-ticket-to-your-distribution).

On macOS 26.5, `spctl --assess --type execute` rejects known Apple-notarized standalone CLI binaries as valid code that is not an app. That result is not a release failure and must not be mocked into success. The standalone CLI verifier does not call `spctl`, `syspolicy`, or `stapler`, and it does not synthesize quarantine metadata. Those tools remain appropriate gates for actual `.app`, `.dmg`, or `.pkg` targets. Gatekeeper proof for this CLI is naturally quarantined clean-VM execution without a warning or block.

## Gate 0: credential-free preparation

1. Finalize the `CHANGELOG.md` section and synchronize `version.env`, `package.json`, `Sources/remindctl/Version.swift`, and the embedded Info.plist.
2. Run:

   ```bash
   make format
   make check
   make docs-site
   make release-harness
   make release-check TAG=vX.Y.Z
   ```

`make macos-artifact` is an optional credential-free, ad-hoc local candidate. It writes `dist/remindctl-macos-local.zip`; that filename cannot satisfy the official inventory and must never be uploaded.

Local linting requires SwiftLint, ShellCheck, and actionlint.

## Gate 1: protected source and signed tag

After the release commit is on protected `main`, exact-head CI is green, and the tag/public mutation gate is granted:

1. Confirm clean `main` is the live remote default SHA.
2. Create a verified signed annotated `vX.Y.Z` tag at that exact commit.
3. Push the tag, then confirm the exact remote tag object and peeled commit match locally.

`scripts/check-release-source.sh` performs all of these checks and emits the deterministic source proof consumed by later gates. A lightweight or unsigned tag is rejected.

## Gate 2: authorized local signing and notarization

Only after the signing/notary gate is granted, run the official packager through `release-mac-app`'s managed-keychain wrapper. Supply the runtime signing locator and `NOTARYTOOL_PROFILE` through the approved handoff; do not persist either value.

```bash
/Users/steipete/Projects/agent-scripts/skills/release-mac-app/scripts/mac-release \
  codesign-run -- scripts/package-macos-release.sh vX.Y.Z
```

The packager refuses any identity other than OpenClaw Foundation, rejects a missing runtime notary profile, validates an `Accepted` notary response, waits until the online notarization constraint passes, revalidates the live commit/tag proof, and writes the three official assets atomically to `dist/release-vX.Y.Z/`. It does not contact GitHub beyond read-only Git remote proof.

## Gate 3: draft and protected native verification

After the draft mutation gate is granted, run:

```bash
scripts/create-release-draft.sh vX.Y.Z
```

The helper revalidates the local signed/notarized assets, creates a draft with the exact title, changelog body, source commit target, and three assets, then dispatches `.github/workflows/release.yml` from protected `main`. It cannot publish or update Homebrew.

The protected verifier runs independently on native Apple Silicon (`macos-15`) and native Intel (`macos-15-intel`). Each job:

- checks out `github.workflow_sha` with persisted credentials disabled and requires the protected default-branch workflow ref;
- uses the write-visible draft token only to fetch exact release metadata/assets and GitHub's verification of the signed tag object;
- requires the inventory commit to equal the trusted workflow SHA and live remote default SHA;
- removes GitHub content/API tokens and Actions runtime/identity tokens before any signature check or candidate execution;
- checks exact inventory, checksum, archive shape, architectures, version, per-slice identifier/Team/authority/runtime/timestamp/designated requirement/Info.plist, and the online notarization constraint;
- runs `--version` natively with `REMINDCTL_VERSION` unset so an environment override cannot spoof a stale binary.

## Gate 4: clean-VM Gatekeeper and TCC proof

Wait for both draft verifier jobs, then use the separately authorized clean macOS 26.5 VM before publication:

1. Download the draft archive through the VM's normal browser path. Extract it, confirm `com.apple.quarantine` propagated naturally to the binary, and do not add or rewrite the attribute.
2. Execute `remindctl --version` and record that Gatekeeper presents no warning, alert, or execution block. Do not substitute a raw-CLI `spctl` assessment.
3. Record the actual Reminders TCC principal, exercise an upgrade from the prior official binary to the Foundation-signed candidate, and verify Reminders read/write behavior.

Current development grants belong to the host terminal application (Terminal or Ghostty), not to the `remindctl` binary. The stable identifier is preserved, but that is not evidence that a personal-Team to Foundation-Team signature migration preserves permission state. Do not claim continuity until this VM gate exists.

## Gate 5: publish, published verifier, and Homebrew

After the publish gate is granted, use only the fail-closed local helper:

```bash
scripts/publish-release.sh vX.Y.Z
```

It redownloads and re-verifies the exact draft, signed-tag/source proof, title, changelog body, target commit, asset identities, signature, and executable. It performs a final metadata comparison immediately before the single publication state change, waits at least two real-time seconds and into a timestamp bucket strictly later than publication and every asset update, then dispatches the published verifier from protected `main`.

Wait for the exact `verify published vX.Y.Z` workflow run. Both native jobs must succeed at the inventory's source commit after publication. Only then run:

```bash
scripts/update-homebrew.sh vX.Y.Z
```

That helper redownloads and re-verifies the published release, requires the exact successful published verifier and both native jobs, and rejects any verifier run that did not begin strictly later than the current release and every current asset's last update. Immediately before its sole tap mutation, it repeats those checks and byte-compares every proof and asset. It renders `Formula/remindctl.rb` from the current tap blob using the locally verified archive SHA-256, updates that exact blob atomically, updates Homebrew, checks the canonical formula homepage/URL/version/checksum, installs or upgrades, runs `brew test`, and repeats the exact signed-binary verification against the installed binary.

## Closeout

- Confirm GitHub Release notes match the finalized changelog section and exactly three assets exist.
- Reopen `CHANGELOG.md` as the next patch version's `Unreleased` section only after GitHub and Homebrew proof succeeds.
- Commit/push the closeout, wait for exact-head CI, pull `main` with `--ff-only`, and leave the checkout clean.
