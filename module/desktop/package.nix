# Gemini Desktop (macOS) from Google's signed .dmg.
# The pin is written by `nix run .#gemini-desktop-bump` (then commit pin.json); never edit it by hand.
# No fixup: patching any byte would invalidate Google's code signature
# (TeamIdentifier EQHXZ8M8AV, verified 2026-09-22 against this exact pin).
{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
let
  pin = lib.importJSON ./pin.json;
in
stdenvNoCC.mkDerivation {
  pname = "gemini-desktop";
  inherit (pin) version;
  src = fetchurl { inherit (pin) url hash; };
  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    mkdir -p $out/Applications
    cp -R Gemini.app $out/Applications/
  '';
  meta = {
    description = "Gemini Desktop";
    homepage = "https://gemini.google.com/download";
    license = lib.licenses.unfree;
    # The dmg ships a THIN arm64 Mach-O (verified 2026-09-22, `codesign -dv`
    # against this pin's download: "Mach-O thin (arm64)", no x86_64 slice) —
    # unlike blackmatter-claude's universal zip, this is arm64-only, never
    # lib.platforms.darwin.
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
