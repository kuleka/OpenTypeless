# Releasing the OpenTypeless macOS Client

This document describes the release process for the OpenTypeless macOS client.

OpenTypeless is distributed as an **ad-hoc signed** app (no paid Apple Developer account). Users must right-click → Open on first launch to bypass Gatekeeper. Subsequent updates via Sparkle work automatically.

## Sparkle EdDSA Signing Keys

Updates are verified using [Sparkle](https://sparkle-project.org/)'s EdDSA (Ed25519) signatures. This is independent of Apple codesigning — it works with ad-hoc signed builds.

### Key Storage

- **Public Key**: Embedded in `OpenTypeless/Info.plist` as `SUPublicEDKey`
- **Private Key**: Stored securely in the macOS Keychain (automatically managed by Sparkle)

**IMPORTANT**: The private key is NEVER committed to the repository. It is stored only in the macOS Keychain of the machine that generated it.

### Current Public Key

```
TCU0MwULuIK6y0ubIossVr+61PGh/wHZfFrRFc9F2Is=
```

### Generating New Keys (if needed)

If you need to regenerate the signing keys (e.g., if the private key is lost):

1. Download the Sparkle release:
   ```bash
   curl -L -o Sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz"
   tar -xf Sparkle.tar.xz
   ```

2. Run the key generator:
   ```bash
   ./bin/generate_keys
   ```

3. The tool will:
   - Generate a new EdDSA keypair
   - Store the private key in your macOS Keychain
   - Output the public key to stdout

4. Update `OpenTypeless/Info.plist` with the new public key:
   ```xml
   <key>SUPublicEDKey</key>
   <string>YOUR_NEW_PUBLIC_KEY_HERE</string>
   ```

5. **CRITICAL**: Users with older versions will NOT be able to auto-update to versions signed with the new key. They must manually download the new version.

## Release Process

### Prerequisites

- macOS with the Sparkle EdDSA private key in Keychain
- Xcode installed
- `just` command runner: `brew install just`
- `create-dmg`: `brew install create-dmg`
- `gh` (GitHub CLI): `brew install gh` + `gh auth login`

### Quick Release

```bash
cd clients/macos

# 1. Write release notes (creates draft if missing)
just release-notes 1.0.0

# 2. Edit release-notes/v1.0.0.md — remove all TODO markers

# 3. Run the full release pipeline
just release 1.0.0
```

This will:
- Bump version number in Xcode project
- Run tests
- Build a Release configuration, ad-hoc sign the app bundle
- Create a DMG
- Generate `appcast.xml` with Sparkle EdDSA signature
- Create a git tag and push it
- Create a GitHub Release with DMG + appcast attached

### Gatekeeper and Ad-hoc Signing

Since we don't use a paid Apple Developer account:

- The app is signed with an **ad-hoc identity** (`-`), which satisfies macOS code integrity checks but not Gatekeeper's notarization requirement
- On first launch, users will see "macOS cannot verify the developer of this app"
- **Workaround**: Right-click the app → Open → click "Open" in the dialog
- After the first launch, macOS remembers the choice and won't ask again
- Sparkle updates bypass this entirely — once the app is trusted, updates install silently

### If You Later Get a Developer Account

If you obtain a paid Apple Developer Program membership:

1. Change `CODE_SIGN_IDENTITY` in the Xcode project to `Developer ID Application`
2. Set up `xcrun notarytool` credentials
3. In the justfile, replace `just dmg-self-signed` with `just dmg` in the `release` recipe
4. Add back the notarize/staple steps:

   ```bash
   just notarize "${DMG_PATH}"
   just staple "${DMG_PATH}"
   ```

## Appcast Generation

The `just appcast` command automates appcast generation:

1. Validates the DMG exists
2. Downloads Sparkle tools if not present (`bin/generate_appcast`, `bin/sign_update`)
3. Signs the DMG with the EdDSA key from Keychain
4. Generates `appcast.xml` with download URLs pointing to GitHub Releases

### Appcast Hosting

The appcast is configured to be served from GitHub Releases:

```text
SUFeedURL = https://github.com/kuleka/OpenTypeless/releases/latest/download/appcast.xml
```

Each `just release` run uploads `appcast.xml` as a release asset. Sparkle fetches it from the `latest` release permalink.

### Manual Appcast Generation

```bash
just appcast dist/OpenTypeless.dmg
```

## Security Notes

- The Sparkle EdDSA private key is tied to your Mac's Keychain and cannot be exported easily
- Never share or commit the private key
- If you lose the private key, generate new keys — existing users must manually download the next update
- Ad-hoc signing still provides code integrity protection (tampering detection), just not identity verification

## Troubleshooting

### "Update is improperly signed" error

The update was signed with a different EdDSA key than what's in the app's `Info.plist`. Ensure:

1. You're using the correct private key (check Keychain)
2. The public key in `Info.plist` matches the private key used for signing

### Lost private key

1. Generate new keys using `generate_keys`
2. Update `Info.plist` with the new public key
3. Notify users they'll need to manually download the update
4. Future updates will work normally with the new key

### "macOS cannot verify the developer" on first launch

This is expected for ad-hoc signed apps. Users should:

1. Right-click the app → Open
2. Click "Open" in the Gatekeeper dialog
3. Alternatively: `xattr -cr /Applications/OpenTypeless.app`
