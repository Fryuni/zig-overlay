{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  zigSources = builtins.fromJSON (lib.strings.fileContents ./zig.json);
  zlsSources = builtins.fromJSON (lib.strings.fileContents ./zls.json);

  # mkBinaryInstall makes a derivation that installs Zig from a binary.
  mkBinaryInstall = {
    url,
    version,
    sha256,
    zls,
  }:
    pkgs.stdenv.mkDerivation (finalAttrs: {
      inherit version;

      pname = "zig";
      src = pkgs.fetchurl {inherit url sha256;};
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out/{doc,bin,lib}
        [ -d docs ] && cp -r docs/* $out/doc
        [ -d doc ] && cp -r doc/* $out/doc
        [ -d lib ] && cp -r lib/* $out/lib
        [ -f $out/lib/std/zig/system.zig ] && substituteInPlace $out/lib/std/zig/system.zig \
          --replace "/usr/bin/env" "${pkgs.lib.getExe' pkgs.coreutils "env"}"
        cp zig $out/bin/zig
      '';

      passthru = let
        zlsPkg = pkgs.stdenv.mkDerivation (zlsAttrs: {
          pname = "zls";
          version = zls.version;
          src = pkgs.fetchurl {inherit (zls) url sha256;};
          dontConfigure = true;
          dontBuild = true;
          dontFixup = true;
          unpackPhase = ''
            tar -xf "$src"
          '';
          installPhase = ''
            mkdir -p $out/{doc,bin,lib}
            [ -d docs ] && cp -r docs/* $out/doc
            [ -d doc ] && cp -r doc/* $out/doc
            [ -d lib ] && cp -r lib/* $out/lib
            cp zls $out/bin/zls
          '';

          passthru.hook = pkgs.zig.zls.hook.override {zls = zlsAttrs.finalPackage;};
          passthru.zig = finalAttrs.finalPackage;

          meta = finalAttrs.meta;
        });
      in
        (
          if zls == null
          then {}
          else {zls = zlsPkg;}
        )
        // {
          hook = pkgs.zig.hook.override {zig = finalAttrs.finalPackage;};
        };

      meta = with pkgs.lib; {
        description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
        homepage = "https://ziglang.org/";
        license = lib.licenses.mit;
        maintainers = [];
        platforms = lib.platforms.unix;
      };
    });

  # The packages that are tagged releases
  taggedPackages =
    lib.attrsets.mapAttrs
    (k: v: mkBinaryInstall {
      inherit (v.${system}) version url sha256;
        zls = (zlsSources.${k} or {}).${system} or null;
    })
    (lib.attrsets.filterAttrs
      (k: v:
        (builtins.hasAttr system v)
        && (v.${system}.url != null)
        && (v.${system}.sha256 != null)
        && !(lib.strings.hasSuffix "mach" k))
      (builtins.removeAttrs zigSources ["master" "mach-latest"]));

  # The master packages
  masterPackages =
    lib.attrsets.mapAttrs' (
      k: v:
        lib.attrsets.nameValuePair
        (
          if k == "latest"
          then "master"
          else ("master-" + k)
        )
        (mkBinaryInstall {
        inherit (v.${system}) version url sha256;
        zls = (zlsSources.master.${k} or {}).${system} or null;
      })
    )
    (lib.attrsets.filterAttrs
      (k: v: (builtins.hasAttr system v) && (v.${system}.url != null))
      zigSources.master);

  # Mach nominated versions
  # https://machengine.org/docs/nominated-zig/
  machPackages =
    lib.attrsets.mapAttrs
    (k: v: mkBinaryInstall {inherit (v.${system}) version url sha256;})
    (lib.attrsets.filterAttrs (k: v: lib.strings.hasSuffix "mach" k)
      (builtins.removeAttrs zigSources ["master"]));

  # This determines the latest /released/ version.
  latest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames taggedPackages)
  );

  # Latest Mach nominated version
  machLatest = lib.lists.last (
    builtins.sort
    (x: y: (builtins.compareVersions x y) < 0)
    (builtins.attrNames machPackages)
  );
in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  taggedPackages
  // masterPackages
  // machPackages
  // {
    "default" = taggedPackages.${latest};
    mach-latest = machPackages.${machLatest};
  }
