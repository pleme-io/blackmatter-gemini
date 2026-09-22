{
  description = "Blackmatter Gemini — Gemini Desktop (macOS) under full Nix management, no cask";

  inputs = {
    nixpkgs.follows = "substrate/nixpkgs";
    substrate = {
      url = "github:pleme-io/substrate";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      substrate,
      ...
    }:
    (import "${substrate}/lib/blackmatter-component-flake.nix") {
      inherit self nixpkgs;
      name = "blackmatter-gemini";
      description = "Gemini Desktop (macOS) — Nix-managed package + declarative NSUserDefaults preferences";
      modules.homeManager = import ./module {
        userDefaultsHelpers = import "${substrate}/lib/hm-user-defaults-helpers.nix" {
          inherit (nixpkgs) lib;
        };
      };
      overlay = final: prev: {
        gemini-desktop = final.callPackage ./module/desktop/package.nix { };
      };
      # `nix run .#gemini-desktop-bump` (repo root) rewrites the Desktop pin.
      # `gemini-desktop-bump.rs` is a zero-dependency binary compiled directly
      # with `rustc` (no Cargo.toml — see its own header comment), matching
      # blackmatter-claude's `claude-desktop-bump.rs` shape exactly.
      extraApps = pkgs: {
        gemini-desktop-bump = {
          type = "app";
          program = "${
            pkgs.runCommand "gemini-desktop-bump"
              {
                nativeBuildInputs = [
                  pkgs.rustc
                  pkgs.stdenv.cc
                ];
              }
              ''
                mkdir -p $out/bin
                rustc --edition 2021 -O -o $out/bin/gemini-desktop-bump ${./module/desktop/bump.rs}
              ''
          }/bin/gemini-desktop-bump";
        };
      };

      extraChecks = pkgs: {
        gemini-desktop-bump-tests =
          pkgs.runCommand "gemini-desktop-bump-tests"
            {
              nativeBuildInputs = [
                pkgs.rustc
                pkgs.stdenv.cc
              ];
            }
            ''
              rustc --edition 2021 --test -o test-bin ${./module/desktop/bump.rs}
              ./test-bin --test-threads=1
              touch $out
            '';
      };
    };
}
