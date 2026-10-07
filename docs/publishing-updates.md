# Publishing in-app updates

WindowHop 1.0.3 (build 4) introduces Sparkle. Earlier versions require one manual installation of this version. Sparkle reads `appcast.xml` on the main branch, not GitHub's latest-release API. Publishing a ZIP alone does not advertise an in-app update.

## Keys and dependencies

Sparkle 2.10.0 is pinned in Package.swift and Package.resolved. The update-signing private key is in the login Keychain under Sparkle's `WindowHop` account. Only the public key is committed in scripts/sparkle-public-key.txt. Keep the private key safe and back it up securely; never upload it to GitHub. Replacing it would prevent existing installations from verifying updates.

The local app-signing certificate is still used, including for Sparkle's nested helpers. Keep that identity stable. This does not provide Apple notarization.

## Each release

1. Increase both CFBundleShortVersionString and CFBundleVersion in scripts/build.sh. For the next test use 1.0.4 and build 5. Build numbers must always increase.
2. Write release notes in docs/release-v1.0.4.md (matching the version).
3. Run `./scripts/release.sh` from the project folder. Allow the signing tools to use the Keychain when macOS asks. The script builds, signs the app and nested helpers, creates a ZIP, and generates an EdDSA-signed enclosure in appcast.xml. It also writes a checksum file.
4. Upload changed source files, Package.swift, Package.resolved, scripts/build.sh, scripts/release.sh, scripts/sparkle-public-key.txt, and docs to GitHub. Never upload the private signing-identity.txt, .build, or the entire dist folder.
5. Create the stable GitHub release with the matching tag, for example v1.0.4. Attach the exact generated ZIP and checksum. Publish it. Do not re-zip or edit the signed archive afterward.
6. Once the ZIP download is available, upload the generated appcast.xml to the root of main. This is the step that makes the update visible to Sparkle clients. Its URL is https://raw.githubusercontent.com/singhgit2023/WindowHop/main/appcast.xml.

The initial 1.0.3 release follows the same steps. Its feed offers build 4, so installed 1.0.3 clients report up to date. Never publish a feed pointing at an unavailable download.

## Manual test

Install 1.0.3 in Applications and keep it running for the test. Build and publish 1.0.4 without replacing that installed copy. In the installed 1.0.3, choose Check for Updates, Install Update, then Install and Relaunch. Confirm General settings reports 1.0.4 (5), your preferences remain, and switching/permissions still work. Check again to verify the up-to-date result.

Automatic checking and installation start disabled. Users can opt in through General settings. Sparkle may defer automatic installation until the app quits. An app in a read-only location, macOS translocation, or filesystem permissions can prevent installation or require an OS prompt. Test the free self-signed distribution on another Mac before broad release.
