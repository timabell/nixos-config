# Tim's NixOS config

https://github.com/timabell/nixos-config

Flake-based NixOS configuration with disko for declarative disk partitioning,
LUKS encryption, and btrfs.

Also available as a variation for an [isolated development vm](dev-vm.md) to mitigate supply-chain attacks on the primary host.

See [security-boundaries.md](security-boundaries.md) for the threat model and
host / VM / bubblewrap layering this is built around.

## Hosts

Every host shares one base: LUKS + btrfs (`disko/common.nix`) and the
common module set in `modules/common.nix` (base system, user, CLI
tooling, containers, desktop, networking, hardware). All hosts run a
desktop — there are no headless servers. A host's own file under
`hosts/` carries only its hardware specifics (kernel modules, swap,
`stateVersion`).

Reusing this config? The default user is defined in one place —
`modules/user.nix` — change `tim` there.

### Development is sandboxed in the dev VM

All development work happens in the [dev VM](dev-vm.md), never on a
bare-metal host — no npm/dotnet/cargo builds on the primary machines
(supply-chain risk). The dev toolchain lives in `modules/dev-tooling.nix`
and is imported only by the VM. Bare-metal hosts get CLI tooling
(`modules/cli.nix`) and Docker (`modules/containers.nix`), but no
language build toolchains.

## Installing from live USB

### Get the NixOS live USB

Download a NixOS ISO from <https://nixos.org/download/> — either the
Graphical or the Minimal installer image works (these instructions only
need a shell). Write it to a USB stick, replacing `/dev/sdX` with your
USB device — check with `lsblk` first, as picking the wrong device will
wipe that disk:

```sh
sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### Boot the NixOS live USB

**x15 only:** the XPS 15 NVMe drive is not visible to the default NixOS
live environment. At the GRUB boot menu, press `e` to edit the boot entry
and add these kernel parameters to the `linux` line:

```
nvme_core.default_ps_max_latency_us=0 pcie_aspm=off
```

Without these, the installer will not see `/dev/nvme0n1`. On `cog`
this isn't needed — boot the live USB normally.

### Connect to the network

Connect an ethernet cable, or join wifi:

```sh
nmcli device wifi connect "SSID" password "PASSWORD"
```

### Clone this repo

```sh
nix-shell -p git --run \
  'git clone https://github.com/timabell/nixos-config.git' \
  && cd nixos-config
```

### Install with disko-install

**⚠️ WARNING: This will wipe the entire target disk. All existing data will be
destroyed. Make sure you have backups and have specified the correct device.**

This partitions, formats, and installs NixOS in one step. Replace
`<host>` with `x15` or `cog`, and `/dev/nvme0n1` if your drive path
differs:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run 'github:nix-community/disko/latest#disko-install' -- \
  --flake '.#<host>' \
  --disk main /dev/nvme0n1
```

You will be prompted for a LUKS passphrase.

### Two-step install

If the full closure won't fit the live USB's RAM (or the ISO won't boot
and you're installing from another live distro), install the minimal
`<host>-base` first, boot it, then switch to the full config:

```sh
./install-from-live-mint.sh cog-base /dev/nvme0n1
# reboot, get online, then:
sudo nixos-rebuild switch --flake .#cog
```

### Reboot

```sh
reboot
```

Log in as `tim` with the initial password `changeme` and change it immediately:

```sh
passwd
```

### Sign in to Firefox

Sign in to Firefox Sync to restore bookmarks, passwords, and extensions.

### Generate SSH key and add to GitHub

```sh
ssh-keygen
cat ~/.ssh/id_ed25519.pub
```

Add the public key at https://github.com/settings/keys

### Clone this repo (first time only)

Once syncthing is configured, future rebuilds will already have the repo
via syncthing sync.

```sh
mkdir -p ~/repo
git clone git@github.com:timabell/nixos-config.git ~/repo/nixos-config
```

### Tailscale login/add

If rebuilding a machine remove the old host from [tailscale machine list](https://login.tailscale.com/admin/machines) first (to avoid a machine-1 hostname).

```sh
sudo tailscale up --operator=$USER
```

(`--operator` to avoid future need for `sudo`)

### ssh auth

```sh
ssh-copy-id othermachine
ssh othermachine
```

### Configure syncthing

Syncthing is enabled in the NixOS config and starts automatically. Open
http://localhost:8384 in a browser to pair with your other machines and
set up shared folders.

## Making changes

Edit the nix files then rebuild and switch:

```sh
cd ~/repo/nixos-config
sudo nixos-rebuild switch --flake .#"$(hostname)"
```

This doesn't reboot. It restarts/reloads only the services that changed
(e.g. adding syncthing starts the syncthing service). Kernel or bootloader
changes update the boot entry but only take effect on the next reboot.

If something breaks, reboot and pick a previous generation from the
systemd-boot menu.

## Useful references

- [NixOS manual](https://nixos.org/manual/nixos/stable/) -- the main reference for NixOS configuration options
- [NixOS option search](https://search.nixos.org/options) -- searchable index of every NixOS option
- [Nixpkgs package search](https://search.nixos.org/packages) -- find packages to add to `environment.systemPackages`
- [Nix language basics](https://nix.dev/tutorials/nix-language.html) -- introduction to the Nix expression language
- [Disko documentation](https://github.com/nix-community/disko/blob/master/docs/INDEX.md) -- declarative disk partitioning, used here for LUKS + btrfs layout
- [disko-install](https://github.com/nix-community/disko/blob/master/docs/disko-install.md) -- the one-step install command used above
- [Flakes](https://wiki.nixos.org/wiki/Flakes) -- how `flake.nix` and `flake.lock` work
- [nixos-hardware](https://github.com/NixOS/nixos-hardware) -- hardware-specific NixOS modules (this config uses the Dell XPS 15 profile)
- [Home Manager](https://github.com/nix-community/home-manager) -- manage dotfiles and user-level packages declaratively (a natural next step)
- [NVMe drive not detecting after calameres initiates - Help - NixOS Discourse](https://discourse.nixos.org/t/nvme-drive-not-detecting-after-calameres-initiates/32108/14)
- [Cinnamon - Official NixOS Wiki](https://wiki.nixos.org/wiki/Cinnamon)
- [Laptop setup notes](https://0x5.uk/2019/08/20/laptop-setup/)
