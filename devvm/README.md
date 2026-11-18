# devvm — sandboxed dev VM

A NixOS qcow2 image that runs under QEMU/KVM (via virt-manager).

Isolates development work exposed to supply-chain attacks from host data.

See also the more granular [bubblewrap sandbox](https://github.com/timabell/sandbox) for isolating individual processes more tightly (such as preventing LLM Agents looking where they shouldn't).

- XFCE desktop (lightweight)
- JetBrains Toolbox, VS Code, the dev tools from `modules/dev-tooling.nix`
- SPICE: bidirectional clipboard, display auto-resize
- virtiofs shares from host (`~/no-sync/devvm` → `~/work`, `~/repo` → `~/repo` in the VM)
- No GPG keys in the VM. Signing is host-only.
- Outbound-only firewall

## How the image is built

The flake build *is* the installer — no live USB, no `nixos-install`. The
flow is two-stage:

1. Build a **bare** NixOS qcow2 (`.#devvm-base`) — small closure, fast.
2. Boot it, then `nixos-rebuild switch` to the **full** config inside the
   running VM — pulls store paths from `cache.nixos.org` instead of
   running the slow `cptofs` step a second time.

This avoids the ~hour of single-threaded ext4 packing that a full image
build would take.

Set up the host first (pick your host's section), then build and boot
the VM.

## Host setup: Debian / Ubuntu

### Install Nix

Pick one:

**a) Determinate Systems installer** (easiest, flakes enabled by default):

```
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix \
  | sh -s -- install
```

- Landing page: <https://determinate.systems/nix-installer/>
- GitHub: <https://github.com/DeterminateSystems/nix-installer>
- Script source: <https://install.determinate.systems/nix>

**b) Upstream Nix installer** (flakes need a manual opt-in):

```
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Then add `experimental-features = nix-command flakes` to either
`/etc/nix/nix.conf` or `~/.config/nix/nix.conf`.

- Landing page: <https://nixos.org/download/>
- Script source: <https://nixos.org/nix/install>

Open a fresh shell so `nix` is on `PATH`.

### Clone the repo

```
git clone https://github.com/timabell/nixos-config.git
cd nixos-config
```

### Install libvirt

```
devvm/host-prereqs.sh
```

Installs libvirt + KVM, virt-manager, OVMF and virtiofsd, and adds you to
the `libvirt` group. Log out and back in for the group to apply.

libvirt runs qemu as `libvirt-qemu` (`qemu` on Fedora / Arch).

## Host setup: NixOS (fleet host from this repo)

Nix, the repo and libvirt (`modules/libvirt.nix`) are already there.
After the first switch that adds libvirt, log out and back in for the
`libvirtd` group.

The `default` network is defined but not started:

```
sudo virsh net-autostart default
sudo virsh net-start default
```

libvirt runs qemu as `qemu-libvirtd`.

## Build and boot the VM

### Create the VM

```
devvm/create.sh
```

Memory, CPU count and disk path are variables at the top of
`devvm/define.sh`.

Open the console with `virt-viewer devvm`, or find `devvm` in
virt-manager.

After editing `define.sh`, run `devvm/apply-changes.sh` (keeps the
disk). For a fresh disk, run
`devvm/delete.sh --disk` then `devvm/create.sh`.

### First boot of the bare image

You'll land in a TTY logged in as `tim` (autologin is enabled in the bare
image). Run `passwd` to change the default password (`changeme`).

Networking comes up via DHCP. Confirm:

```
ping -c1 cache.nixos.org
```

### Switch to the full devvm config

From inside the running bare VM, apply the full config (XFCE, IDEs,
etc.):

```
cd ~/repo/nixos-config
./update-current-host.sh
```

`~/repo` is the host's `~/repo`, shared in, so this applies your local
checkout, unpushed changes included. If the repo isn't at
`~/repo/nixos-config` on the host, use
`sudo nixos-rebuild switch --flake github:timabell/nixos-config#devvm`.

This downloads pre-built store paths from `cache.nixos.org` rather than
running `cptofs` — much faster than rebuilding the qcow2 from scratch.
First switch is the bulk of the work; subsequent switches are quick.

Reboot to land in the XFCE greeter:

```
sudo reboot
```


After reboot:

- Log in as `tim` at the LightDM greeter.
- Network should come up via NetworkManager (the XFCE applet is in the
  tray).

GPG: there are deliberately no keys. `git commit` works without `-S`. If
you hit a remote that enforces signing, do the final commit/push from the
host.

## Daily use

### Getting code into the VM

The host's `~/no-sync/devvm/` is auto-mounted at `/home/tim/work/` in the
VM via virtiofs. Anything dropped there from the host is visible
immediately inside the VM and vice versa.

Two patterns:

- **Clone directly inside the VM.** `git clone https://github.com/foo/bar`
  in `/home/tim/work/`. Code lives on the share; visible from host for
  backup, host-side tooling, etc.
- **Clone on the host into `~/no-sync/devvm/<repo>/`.** Same end state.
  Useful when you've already got the repo somewhere on the host.

The host's `~/repo/` is also mounted, read-write, at `/home/tim/repo/`.
See [security-boundaries.md](../security-boundaries.md) for why that's OK.

### SSH from host

The VM runs sshd. Paste-friendly terminal access:

```
ssh devvm
mosh devvm
```

On a NixOS host the libvirt NSS module (`modules/libvirt.nix`) resolves
`devvm` to its current IP. Elsewhere, `virsh domifaddr devvm` to find it.
`ssh-copy-id devvm` once to stop the password prompts.

Useful when the SPICE clipboard is being flaky, or for running long
commands from a host terminal where paste already works.

### Per-project dev shells (node, dotnet, rust, …)

The VM has `direnv` + `nix-direnv` wired into zsh. Per-project runtime
versioning happens via a flake.nix + `.envrc` in each repo, replacing
mise / nvm / asdf. Example for a Node project that had a `.nvmrc`:

`flake.nix`:

```nix
{
  description = "<project name> dev shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ nodejs_24 ];
      };
    };
}
```

`.envrc`:

```
use flake
```

Then once per project:

```
git add flake.nix .envrc
direnv allow
```

`cd` out and back in — direnv loads the shell, `node --version`
reflects the flake. `git rm .nvmrc` (and friends) once you're satisfied
with the flake.

For other languages add to `packages`: `dotnet-sdk_8`, `rustup` or
`rustc cargo`, `python3`, `go`, etc.

### Iterating on the devvm NixOS config itself

The flake repo lives at `~/repo/nixos-config/` inside the VM (the host
checkout, shared in). Edit on host, the change is live in the VM. Apply:

```
cd ~/repo/nixos-config
./update-current-host.sh
```

For a full reset (e.g. after major changes), reboot:

```
sudo reboot
```

### Risky-command sandbox inside the VM

`bubblewrap` (`bwrap`) is installed for nested sandboxing of single
commands inside the VM — typically LLM agents running with permission
bypass. See [security-boundaries.md](../security-boundaries.md) for the
threat model. The VM is the host-protection boundary; bwrap inside the
VM is defence-in-depth against an agent stepping outside its remit
within the VM.

### Handling `.env` secrets

Having `.env` files on disk leaves them exposed to marauding malware and LLMs. While not possible to completely protect with this setup we can raise the bar. This vm includes [gopass](https://www.gopass.pw/) which can be used to encryt secrets and supply them just-in-time to run a process (usually a webserver/api under development).

```sh
gopass insert project/environment/SECRET_NAME # prompts for value
gopass list
gopass show project/environment/SECRET_NAME
gopass env project/environment/ npm run # run a command (e.g. npm run) with secrets available as env vars
```

## Updating the VM later

Rebuild in place from inside the VM, the same as the first switch:

```
cd ~/repo/nixos-config
./update-current-host.sh
```

This is the workflow for almost everything. No need to rebuild and
re-import the qcow2 unless you're recovering from breakage or want a
fresh disk.

### Building a full qcow2 from scratch (rarely needed)

`nix build .#devvm` builds the full config as a fresh qcow2 — everything
the in-place switch would install, packed via `cptofs`. This is **slow**
(60+ minutes of single-threaded ext4 packing) and only worth it if you
specifically want a clean-state disk image (e.g. handing one to someone
else, or reproducing the VM from zero).

## Expanding the disk later

```
devvm/resize.sh 200G
```

Keeps everything on the disk. The cap is how much of the host's disk the
VM may fill, so keep it under the host's free space. The default for new
VMs is in `devvm/create.sh`.

## Changing the shared folders

The host folders are `SHARE_DIR` and `REPO_DIR` in `devvm/define.sh`. Shares are
attached when the domain is defined, so run `devvm/apply-changes.sh`
after changing them.

## Troubleshooting

- **VM won't boot / GRUB or BIOS error** — firmware must be UEFI (OVMF),
  not BIOS. Edit the VM XML and confirm `<os firmware="efi">` (or set it
  via virt-manager → Overview → Firmware → UEFI).
- **No clipboard sharing** — confirm Display is Spice (not VNC) and that
  `spice-vdagentd` is running inside the VM (`systemctl status spice-vdagentd`).
- **Tiny screen / no auto-resize** — Video must be virtio (or QXL), not Cirrus.
- **virtiofs mount fails: "wrong fs type"** — `virtiofsd` isn't running
  on the host. Install it (see host setup).
- **"command not found: nix-build"** after install — open a new shell so
  `/etc/profile.d/nix.sh` is sourced.
