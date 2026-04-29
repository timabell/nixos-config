# devvm — sandboxed dev VM

A NixOS qcow2 image that runs under QEMU/KVM (via virt-manager).

Isolates development work exposed to supply-chain attacks from host data.

See also the more granular [bubblewrap sandbox](https://github.com/timabell/sandbox) for isolating individual processes more tightly (such as preventing LLM Agents looking where they shouldn't).

- XFCE desktop (lightweight)
- JetBrains Toolbox, VS Code, the dev tools from `modules/development.nix`
- SPICE: bidirectional clipboard, display auto-resize
- Optional: virtiofs share from host (mounted ad-hoc inside the VM, not baked into the config)
- No GPG keys in the VM. Signing is host-only.
- Outbound-only firewall

## Build the qcow2

The flake build *is* the installer — no live USB, no `nixos-install`. The
flow is two-stage:

1. Build a **bare** NixOS qcow2 (`.#devvm-base`) — small closure, fast.
2. Boot it, then `nixos-rebuild switch` to the **full** config inside the
   running VM — pulls store paths from `cache.nixos.org` instead of
   running the slow `cptofs` step a second time.

This avoids the ~hour of single-threaded ext4 packing that a full image
build would take.

### 1. Install Nix

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

**c) Already on Nix / NixOS** — skip this step.

After (a) or (b), open a fresh shell so `nix` is on `PATH`.

### 2. Clone the repo

```
git clone https://github.com/timabell/nixos-config.git
cd nixos-config
```

### 3. Build the bare image

```
nix build .#devvm-base
```

This builds a minimal bootable NixOS image. Small closure → `cptofs`
finishes in minutes, not hours. The full devvm config is layered on top
*inside* the running VM (step 7), where store paths are fetched from
`cache.nixos.org` over the network instead of being packed via the
single-threaded `cptofs` step in the image build.

Result: `result/devvm-base.qcow2` (symlink into the Nix store).

### 4. Place the qcow2 where libvirt can read it

```
sudo install -o libvirt-qemu -g libvirt-qemu -m 0660 \
  result/devvm-base.qcow2 /var/lib/libvirt/images/devvm.qcow2
```

On Debian/Ubuntu the libvirt user/group is `libvirt-qemu`; on Fedora/Arch
it's `qemu`. Adjust if `id libvirt-qemu` says no such user.

### 5. Resize the qcow2 to 80 GiB before first boot

The bare image is built tiny (~4 GiB) because `cptofs`/LKL OOMs trying to
handle ext4 metadata for a large filesystem at build time. Resize it on
the host now — qcow2 is sparse, so the 80 GiB is a cap, not an upfront
allocation:

```
sudo qemu-img resize /var/lib/libvirt/images/devvm.qcow2 80G
```

`growPartition` + `autoResize` (from the imported `disk-image.nix`)
expand the partition and root filesystem to fill the new disk on first
boot.

### 6. Define and start the VM

Run the install script (in this repo):

```
./dev-vm-install.sh
```

It calls `virt-install` with the right flags for an imported existing
disk: UEFI firmware (Secure Boot off — NixOS systemd-boot isn't signed
against the default Microsoft keys), virtio disk, virtio video, SPICE
display, host-passthrough CPU, 8 GiB / 4 vCPU. Edit the variables at
the top of the script if you want different memory / CPU counts or a
different image path.

Open the console to see what's going on:

```
virt-viewer devvm
```

Or use virt-manager — `devvm` will appear in the list.

If you want a virtiofs shared folder from the host, see "Adding a
virtiofs share" below — it's intentionally not part of the baseline VM
setup, and is opt-in via flags in the script.

To recreate the domain (e.g. after editing the script):

```
virsh destroy devvm 2>/dev/null
virsh undefine devvm --nvram
./dev-vm-install.sh
```

The `--nvram` flag is important: without it the previous SB-enabled
NVRAM file lingers and the new domain inherits it.

### 7. First boot of the bare image

You'll land in a TTY logged in as `tim` (autologin is enabled in the bare
image). Run `passwd` to change the default password (`changeme`).

Networking comes up via DHCP. Confirm:

```
ping -c1 cache.nixos.org
```

### 8. Switch to the full devvm config

From inside the running bare VM, apply the full config (XFCE, IDEs,
etc.):

```
sudo nixos-rebuild switch --flake github:timabell/nixos-config#devvm
```

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

### SSH from host

The VM runs sshd. Paste-friendly terminal access:

```
virsh domifaddr devvm           # find the IP
ssh tim@<ip>
```

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

The flake repo lives at `~/work/nixos-config/` inside the VM (the share
copy). Edit on host, the change is live in the VM. Apply:

```
cd ~/work/nixos-config
sudo nixos-rebuild switch --flake .#devvm
```

For a full reset (e.g. after major changes), reboot:

```
sudo reboot
```

### Risky-command sandbox inside the VM

`bubblewrap` (`bwrap`) is installed for nested sandboxing of single
commands inside the VM — typically LLM agents running with permission
bypass. See [security-boundaries.md](security-boundaries.md) for the
threat model. The VM is the host-protection boundary; bwrap inside the
VM is defence-in-depth against an agent stepping outside its remit
within the VM.

## Updating the VM later

Rebuild in place from inside the VM — the same command you used in step 8:

```
sudo nixos-rebuild switch --flake github:timabell/nixos-config#devvm
```

Or, if you have the repo cloned inside the VM:

```
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#devvm
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

If 80 GiB ever isn't enough, raise the cap on the existing qcow2 (no
rebuild needed) — qcow2 is sparse so this is cheap:

1. Shut down the VM.
2. On the host:

   ```
   sudo qemu-img resize /var/lib/libvirt/images/devvm.qcow2 200G
   ```

3. Boot the VM. `autoResize` + `growPartition` (provided by the imported
   `disk-image.nix` module) expand the partition and root filesystem to
   fill the new space.

You can also bake a new default into the build by editing
`virtualisation.diskSize` in `hosts/devvm-base.nix` — only matters for fresh
qcow2 builds, doesn't affect an already-deployed VM.

## Adding a virtiofs share

Deliberately not in the baseline VM config — keeps host-specific
decisions out of the system config. To enable on a per-VM basis:

1. **Install `virtiofsd` on the host** (Debian/Ubuntu: `apt install
   virtiofsd`; Fedora: `dnf install virtiofsd`; Arch: `pacman -S
   virtiofsd`). libvirt rejects the older qemu-bundled virtiofsd.

2. **Recreate the VM with shared memory + filesystem.** In
   `dev-vm-install.sh`, set `SHARE_DIR` and uncomment the two flags
   marked "virtiofs". `virsh undefine devvm --nvram` first if the
   domain already exists, then re-run the script.

3. **Mount inside the VM** when you need it:

   ```
   sudo mkdir -p /home/tim/work
   sudo mount -t virtiofs shared /home/tim/work
   ```

   Replace `shared` with whatever target tag you used on the host side.

For something more persistent without involving NixOS, add a one-shot
systemd unit inside the VM by hand. Don't add `fileSystems` entries to
the flake — that re-couples this config to a host-side decision.

## Troubleshooting

- **VM won't boot / GRUB or BIOS error** — firmware must be UEFI (OVMF),
  not BIOS. Edit the VM XML and confirm `<os firmware="efi">` (or set it
  via virt-manager → Overview → Firmware → UEFI).
- **No clipboard sharing** — confirm Display is Spice (not VNC) and that
  `spice-vdagentd` is running inside the VM (`systemctl status spice-vdagentd`).
- **Tiny screen / no auto-resize** — Video must be virtio (or QXL), not Cirrus.
- **virtiofs mount fails: "wrong fs type"** — `virtiofsd` isn't running
  on the host. Install it (see "Adding a virtiofs share").
- **"command not found: nix-build"** after install — open a new shell so
  `/etc/profile.d/nix.sh` is sourced.
