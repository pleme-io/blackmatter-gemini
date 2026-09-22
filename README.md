# blackmatter-gemini

Gemini Desktop (macOS) under full Nix management — no cask, no self-updater.
The app is a pinned derivation from Google's signed `.dmg`; the ONLY upgrade
path is `nix run .#gemini-desktop-bump` (rewrites the pin) + `nix flake
update` in a consumer.

## What it manages

| File | Content | Method |
|------|---------|--------|
| `Applications/Gemini.app` | The app itself, pinned in `module/desktop/pin.json` | `home.packages` |
| `~/Library/Preferences/com.google.GeminiMacOS.plist` | Declared preference keys | Non-destructive PlistBuddy merge, at HM activation |

The plist merge is deliberately non-destructive: only the keys named in
`preferences` are forced. Anything Gemini writes at runtime on its own
(window position, auth/session state, first-run flags) is left alone.

## Flake outputs

- `homeManagerModules.default` — home-manager module at `blackmatter.components.gemini`
- `overlays.default` — `gemini-desktop` package
- `apps.<system>.gemini-desktop-bump` — refresh `module/desktop/pin.json`

## Quick start

```nix
{
  inputs.blackmatter-gemini.url = "github:pleme-io/blackmatter-gemini";
}
```

```nix
blackmatter.components.gemini.desktop = {
  enable = true;

  # Non-destructive NSUserDefaults merge — only these keys are forced.
  preferences = {
    # example keys, verify against the app's own domain before relying on them
  };
};
```

## Why no self-updater, and why that's intentional

The app lives in the read-only Nix store; `dontFixup = true` preserves
Google's code signature byte-for-byte, so any runtime patch (including an
auto-updater rewriting the binary) would break it anyway. Upgrades are a pin
bump + rebuild, same as every other Nix-managed app in this fleet.

## Bumping the pin

Google publishes no versioned "latest" feed for Gemini Desktop (unlike
Anthropic's `RELEASES.json` for Claude Desktop) — the download URL is a
constant Google overwrites in place on every release. `gemini-desktop-bump`
therefore always re-downloads the current `.dmg`, mounts it with `hdiutil`,
and reads `CFBundleVersion` out of the app bundle's own `Info.plist` to
decide whether the pin is stale.

```
nix run .#gemini-desktop-bump
git add module/desktop/pin.json
git commit -m "gemini-desktop: bump to <version>"
```

## Structure

- `module/default.nix` — home-manager module entry point (thin import)
- `module/desktop/package.nix` — the pinned derivation (`undmg` extraction, no fixup)
- `module/desktop/pin.json` — version/url/hash, written only by the bump tool
- `module/desktop/bump.rs` — zero-dependency Rust pin-refresh tool
- `module/desktop/home.nix` — options + the NSUserDefaults activation wiring

## Verified against the pin (2026-09-22)

- App: `Gemini.app`, bundle ID `com.google.GeminiMacOS`
- Architecture: thin arm64 Mach-O (no x86_64 slice) — `platforms = [ "aarch64-darwin" ]`
- Signature: valid, `TeamIdentifier=EQHXZ8M8AV`
