# Gemini Desktop — Home Manager arm.
#
# The package is a derivation (./package.nix, pinned in ./pin.json). App
# preferences are NSUserDefaults, not a config file the app reads at launch
# (unlike Claude Desktop's claude_desktop_config.json) — Gemini Desktop keeps
# its settings in ~/Library/Preferences/com.google.GeminiMacOS.plist and reads
# that domain at runtime like any other macOS app. `mkUserDefaultsActivation`
# (substrate) is the typed surface for that: a non-destructive PlistBuddy
# merge at HM activation time, so keys Gemini itself writes (window position,
# auth/session state, first-run flags) are left alone and only the keys named
# in `preferences` are forced.
#
# There is no managed-policy darwin arm (contrast blackmatter-claude's
# darwin.nix, /Library/Managed Preferences/…): Gemini Desktop has no
# documented MDM-managed-preferences domain, so there is nothing to render
# there yet. If Google publishes one, add a sibling darwin.nix mirroring that
# shape — do not fold it into this file's `preferences`, which is scoped to
# the per-user domain.
{ userDefaultsHelpers }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.blackmatter.components.gemini.desktop;
  inherit (userDefaultsHelpers) mkUserDefaultsActivation;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.blackmatter.components.gemini.desktop = {
    enable = mkEnableOption "Gemini Desktop (macOS) from Nix, with declarative NSUserDefaults preferences";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "Gemini Desktop package, pinned in module/desktop/pin.json.";
    };

    domain = mkOption {
      type = types.str;
      default = "com.google.GeminiMacOS";
      description = ''
        The app's NSUserDefaults domain. Verified 2026-09-22 against the pinned
        build's own Info.plist (`CFBundleIdentifier`) — override only if Google
        ships a bundle-identifier change under a new pin.
      '';
    };

    preferences = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Keys merged into ~/Library/Preferences/''${domain}.plist at Home
        Manager activation. Non-destructive: only these keys are forced;
        anything the app writes at runtime is left alone. `{ }` (default)
        makes no activation entry at all — see mkUserDefaultsActivation.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.isDarwin;
            message = "blackmatter.components.gemini.desktop: Gemini Desktop is packaged for macOS only.";
          }
        ];

        home.packages = [ cfg.package ];
      }

      (mkUserDefaultsActivation {
        name = "gemini-desktop-preferences";
        inherit (cfg) domain;
        homeDirectory = config.home.homeDirectory;
        settings = cfg.preferences;
      })
    ]
  );
}
