# Nix Flake for Zig

This repository is a Nix flake packaging the [Zig](https://ziglang.org)
compiler. The flake mirrors the binaries built officially by Zig and
does not build them from source.

This repository is meant to be consumed primarily as a flake but the
`default.nix` can also be imported directly by non-flakes, too.

The flake outputs are documented in `flake.nix` but an overview:

- Default package and "app" is the latest released version
- `packages.<version>` for a tagged release
- `packages.master` for the latest nightly release
- `packages.master-<date>` for a nightly release
- `overlays.default` is an overlay that adds `zigpkgs` to be the packages
  exposed by this flake
- `templates.compiler-dev` to setup a development environment for Zig
  compiler development.

## Fork notice

This repo is a fork of https://github.com/mitchellh/zig-overlay by Mitchell Hashimoto, which seems to be unmaintained beyond the automatic bot updates.
There are pending PRs to that repo fixing reproducibility problems and upgrading it to new Nixpkgs releases, but the PRs have been ignored so far.
I don't know whether Mitchell no longer uses his overlay or if the overlay works for him as is and so he doesn't touch it.

I made this fork for me to keep it up to date, merge the PRs people have been sending to upstream and make some improvements myself.
This was mostly for myself, but if others want to send PRs with features or fixes it is all welcome :)

### Notable changes

- `env` shebang is replaced with a stable nix-store reference (from [this pr](https://github.com/mitchellh/zig-overlay/pull/62))
- Pruned old versions of zig nightly build (pruned to 2025-03-02), newer versions are added daily
- All zig packages have a zls package inside of it if there is a zls build compatible with it (e.g. `master-2025-03-02` has `master-2025-03-02.zls`)

## Usage

### Flake

In your `flake.nix` file:

```nix
{
  inputs.zig.url = "github:Fryuni/zig-overlay";

  outputs = { self, zig, ... }: {
    ...
  };
}
```

In a shell:

```sh
# run the latest released version
$ nix run 'github:Fryuni/zig-overlay'
# open a shell with nightly version dated 2021-02-13 (oldest version available)
$ nix shell 'github:Fryuni/zig-overlay#master-2021-02-13'
# open a shell with latest nightly version
$ nix shell 'github:Fryuni/zig-overlay#master'
# open a shell with latest Mach nominated version
$ nix shell 'github:Fryuni/zig-overlay#mach-latest'
```

### Adding zig as a package

To access zig as a package:

In your `flake.nix` file:

```nix
{
  inputs.zig.url = "github:Fryuni/zig-overlay";

  outputs = { self, zig, ... }: {
    ...
    modules = [
      {nixpkgs.overlays = [zig.overlays.default];}
      ...
      ...
    ];
  };
}
```

In your `configuration.nix` file :

````nix
    {pkgs,inputs, ...}: {
    ...
    environment.systemPackages = [
      pkgs.zigpkgs.master # or <version>/master-<date>/
    ]
}

### Compiler Development

This flake outputs a template that makes it easy to work on the Zig
compiler itself. If you're looking to contribute to the Zig compiler,
here are the easy steps to setup a working development environment:

```sh
# clone zig and go into that directory
$ git clone https://github.com/ziglang/zig.git
$ cd zig
# setup the template
$ nix flake init -t 'github:Fryuni/zig-overlay#compiler-dev'
# Two options:
# (1) start a shell, this forces bash
$ nix develop
# (2) If you have direnv installed, you can start the shell environment
# in your active shell (fish, zsh, etc.):
$ direnv allow
````

## FAQ

### Why is a Nightly Missing?

There are two possible reasons:

1. The Zig download JSON that is used to generate this overlay only shows
   the latest _master_ release. It doesn't keep track of historical releases.
   If this overlay wasn't running or didn't exist at the time of a release,
   we could miss a day. This is why historical dates beyond a certain point
   don't exist; they predate this overlay (or original overlays this derives
   from).

2. The official Zig CI only generates a master release if the CI runs
   full green. During certain periods of development, a full day may go by
   where the master branch of the Zig compiler is broken. In this scenario,
   a master build (aka "nightly") is not built or released at all.
