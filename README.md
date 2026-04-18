# Tim's NixOS config

https://github.com/timabell/nixos-config

Flake-based NixOS configuration with disko for declarative disk partitioning,
LUKS encryption, and btrfs.

## Installing from live USB

### 1. Boot the NixOS live USB

The XPS 15 NVMe drive is not visible to the default NixOS live environment.
At the GRUB boot menu, press `e` to edit the boot entry and add these kernel
parameters to the `linux` line:

```
nvme_core.default_ps_max_latency_us=0 pcie_aspm=off
```

Without these, the installer will not see `/dev/nvme0n1`.

### 2. Connect to the network

Connect an ethernet cable, or join wifi:

```sh
nmcli device wifi connect "SSID" password "PASSWORD"
```

### 3. Clone this repo

```sh
nix-shell -p git --run \
  'git clone https://github.com/timabell/nixos-config.git' \
  && cd nixos-config
```

### 4. Install with disko-install

**⚠️ WARNING: This will wipe the entire target disk. All existing data will be
destroyed. Make sure you have backups and have specified the correct device.**

This partitions, formats, and installs NixOS in one step. Replace
`/dev/nvme0n1` if your drive path differs:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run 'github:nix-community/disko/latest#disko-install' -- \
  --flake '.#xps15' \
  --disk main /dev/nvme0n1
```

You will be prompted for a LUKS passphrase.

### 5. Reboot

```sh
reboot
```

Log in as `tim` with the initial password `changeme` and change it immediately:

```sh
passwd
```

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
