# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Tim's personal NixOS configuration: a flake managing several machines plus an
isolated development VM. Uses disko for declarative LUKS + btrfs partitioning
and home-manager for user-level config.

## Commands

Rebuild the current machine after editing nix files (does not reboot; restarts
only changed services):

```sh
sudo nixos-rebuild switch --flake .#"$(hostname)"   # or: ./update-current-host.sh
```

Rebuild the dev VM (run inside the VM): `./update.devvm.sh`

Update flake inputs (nixpkgs pins): `./update-pkg-cache.sh`

Build a dev VM disk image: `nix build .#devvm-base` (fast) or `.#devvm` (slow,
fresh disk only) → `result/*.qcow2`.

Check evaluation without switching: `nixos-rebuild build --flake .#<config>` or
`nix flake check`.

There is no test suite — validation is "does it build and switch."

## Configurations

`flake.nix` exposes these `nixosConfigurations`:

- `x15`, `cog` — bare-metal fleet hosts (`.full`). Both share everything except
  hardware.
- `x15-base`, `cog-base` — minimal systems for the two-step install (see below).
- `devvm` — full dev VM; `devvm-base` — minimal VM for the two-step image build.

**Two-step install pattern:** a `.full` closure is too big to realise in a live
USB's RAM-backed store, so you install/boot the `-base` config (small closure)
then `nixos-rebuild switch` to `.full`, which builds into the real on-disk
store. Same flow for the VM (`devvm-base` image → boot → switch to `devvm`).

## Architecture

**Layering.** Every bare-metal host is built by the `fleetHost` function in
`flake.nix` from one hardware definition (`hosts/<name>.nix`) plus:
`disko/common.nix` (LUKS + btrfs) → `modules/common.nix` (the shared base) →
home-manager (`home/tim.nix` + `home/cinnamon.nix`). `modules/common.nix`
imports the base/user/cli/containers/desktop/networking/hardware/sandbox
modules. A per-host file carries *only* hardware specifics (kernel modules,
swap, `stateVersion`). All hosts run a desktop — there are no headless servers,
so desktop lives in the common base.

**The dev VM is assembled separately** (`devvmModules` in `flake.nix`, not via
`fleetHost`). It is the only config that imports `modules/dev-tooling.nix` — the
language build toolchains (npm/dotnet/cargo/etc.). This is deliberate: **no
development builds run on bare-metal hosts** (supply-chain risk). Bare-metal
hosts get CLI tooling (`modules/cli.nix`) and Docker (`modules/containers.nix`)
but no language toolchains. See `security-boundaries.md` for the full threat
model, and `dev-vm.md` for VM setup/operation.

**The `sandbox` command** (`modules/sandbox/`, vendored from
[timabell/sandbox](https://github.com/timabell/sandbox)) runs a single risky
command inside a per-process bubblewrap sandbox: binds the given working
tree(s) at `~/work`, keeps outbound network, blocks the host home. It exists to
run Claude Code confined. Claude Code is injected into the sandbox via
`SANDBOX_EXTRA_PATH` rather than installed on the host — so on bare-metal hosts
`claude` runs *only* inside `sandbox`, never bare. Its state persists in
`~/.local/share/sandboxed-claude` (separate from any real `~/.claude`). The dev
VM also installs claude-code on the normal PATH, so there it works both in and
out of the sandbox.

## Overlays (flake.nix)

Non-nixpkgs and freshened packages are wired in via overlays defined in
`flake.nix`. When touching these, read the comment above each overlay — several
document a bump procedure (set `hash`/`vendorHash` to `lib.fakeHash`, rebuild,
paste back the hash nix prints).

- `unstableOverlay` — pulls specific packages from nixpkgs-unstable; **devvm-only**.
- `claudeCodeOverlay`, `ghosttyOverlay` — narrow overlays that freshen only one
  package from unstable on bare-metal hosts (claude-code releases weekly;
  Ghostty <1.3 segfaults because our hardened kernel disables io_uring).
- `gitopolisOverlay` — from its own flake input.
- `lazydockerProfilesOverlay`, `schemaExplorerOverlay`, `beadsTuiOverlay` — built
  from Tim's forks / pinned commits, not in nixpkgs.

## Conventions

- The default user `tim` is defined once in `modules/user.nix` — change it there
  if reusing this config.
- nixpkgs is pinned to stable `25.05`; reach for unstable only via a narrow
  overlay, keeping the rest of the host on stable.
- `dotfiles/` holds raw config files deployed by home-manager (`home/tim.nix`,
  `home/cinnamon.nix`); edit these rather than hand-placing files in `~`.
- Keep the "why" in comments: this repo's nix files carry unusually detailed
  rationale comments (kernel/firmware quirks, install ordering, security
  boundaries). Preserve and extend that style when editing.
