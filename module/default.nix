# Gemini Desktop — Home Manager module entry point.
#
# One component today (desktop), so this is a thin import rather than
# assembling several arms the way blackmatter-claude's default.nix does for
# Claude Code + Claude Desktop. Split further only when a second component
# (e.g. a Gemini CLI) actually lands — do not pre-build the seam.
{ userDefaultsHelpers }:
{ ... }:
{
  imports = [ (import ./desktop/home.nix { inherit userDefaultsHelpers; }) ];
}
