# devvm — sandboxed dev VM

A NixOS qcow2 image that runs under QEMU/KVM (via virt-manager).

Isolates development work exposed to supply-chain attacks from host data.

See also the more granular [bubblewrap sandbox](https://github.com/timabell/sandbox) for isolating individual processes more tightly (such as preventing LLM Agents looking where they shouldn't).

- XFCE desktop (lightweight)
- JetBrains Toolbox, VS Code, the dev tools from `modules/development.nix`
- SPICE: bidirectional clipboard, display auto-resize
- Virtiofs: one shared folder from host → `/home/tim/work` in VM
- No GPG keys in the VM. Signing is host-only.
- Outbound-only firewall

## Build the qcow2

The flake build *is* the installer. Output is a fully-installed disk image —
no live USB, no `nixos-install` step.

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

### 3. Build the image

```
nix build .#devvm
```

First build pulls a lot — expect 15–30 minutes and several GB of nixpkgs
downloads. Subsequent rebuilds are fast.

The result is at `result/devvm.qcow2` (a symlink into the Nix store).

### 4. Place the qcow2 where libvirt can read it

```
sudo install -o libvirt-qemu -g libvirt-qemu -m 0660 \
  result/devvm.qcow2 /var/lib/libvirt/images/devvm.qcow2
```

On Debian/Ubuntu the libvirt user/group is `libvirt-qemu`; on Fedora/Arch
it's `qemu`. Adjust if `id libvirt-qemu` says no such user.

The image ships with an 80 GiB cap (set via `virtualisation.diskSize` in
`hosts/devvm.nix`). qcow2 is sparse, so actual host disk use only grows
as the guest writes — the 80 GiB is a ceiling, not an upfront allocation.

## Create the VM in virt-manager

1. **File → New Virtual Machine → Import existing disk image**
2. Provide path: `/var/lib/libvirt/images/devvm.qcow2`. OS type: Linux,
   Generic Linux 2022 (or NixOS if listed).
3. Memory: 8192 MiB or more (Rider is hungry). CPUs: 4+.
4. Tick **Customize configuration before install**.

In the customization screen:

- **Overview → Firmware** — set to **UEFI** (OVMF). The image is built
  with systemd-boot + an ESP partition, so it will not boot under BIOS
  firmware. If "UEFI" isn't offered, install `edk2-ovmf` (or your distro's
  equivalent OVMF package) on the host and restart libvirtd.
- **Display Spice** — keep, set Listen type to "None".
- **Video** — set to virtio (or QXL as a fallback if virtio gives you trouble). Don't use Cirrus.
- **Channels** — confirm `org.spice-space.webdav.0` and the qemu-ga channel
  are present (they auto-add for Linux guests).
- **Memory** → tick **Enable shared memory** (required for virtiofs).
  Equivalent XML:

  ```xml
  <memoryBacking>
    <source type="memfd"/>
    <access mode="shared"/>
  </memoryBacking>
  ```

- **Add Hardware → Filesystem**:
  - Driver: **virtiofs**
  - Source path: e.g. `/home/<you>/devvm-share` (create this dir first)
  - Target path: `shared` ← must match the tag in `hosts/devvm.nix`

Click **Begin Installation**. (It's not really installing — it just boots
the pre-built image.)

## First boot

- Log in as `tim` / `changeme` at the LightDM greeter.
- `passwd` immediately to change it.
- The shared folder mounts at `/home/tim/work`. Confirm with `mount | grep virtiofs`.
- Network should come up via NetworkManager (the XFCE applet is in the tray).

GPG: there are deliberately no keys. `git commit` works without `-S`. If you
hit a remote that enforces signing, do the final commit/push from the host.

## Updating the VM later

Rebuild in place from inside the VM — the flake exposes
`nixosConfigurations.devvm` for exactly this. Pull the latest config
straight from GitHub:

```
sudo nixos-rebuild switch --flake github:timabell/nixos-config#devvm
```

Or, if you have the repo cloned (e.g. on the shared folder):

```
cd /home/tim/work/nixos-config
sudo nixos-rebuild switch --flake .#devvm
```

This applies config changes to the running VM the same way `nixos-rebuild
switch` works on a normal NixOS host. No need to rebuild and re-import the
qcow2 unless you're recovering from breakage or want a fresh disk.

## Expanding the disk later

If 80 GiB ever isn't enough, raise the cap on the existing qcow2 (no
rebuild needed) — qcow2 is sparse so this is cheap:

1. Shut down the VM.
2. On the host:

   ```
   sudo qemu-img resize /var/lib/libvirt/images/devvm.qcow2 200G
   ```

3. Boot the VM. `autoResize` + `growPartition` (set in `hosts/devvm.nix`)
   expand the partition and root filesystem to fill the new space.

You can also bake a new default into the build by editing
`virtualisation.diskSize` in `hosts/devvm.nix` — only matters for fresh
qcow2 builds, doesn't affect an already-deployed VM.

## Troubleshooting

- **VM won't boot / GRUB or BIOS error** — firmware must be UEFI (OVMF),
  not BIOS. Edit the VM XML and confirm `<os firmware="efi">` (or set it
  via virt-manager → Overview → Firmware → UEFI).
- **virtiofs mount fails on boot** — the VM is configured with `nofail`, so
  it boots anyway. Check `journalctl -u home-tim-work.mount` and confirm
  the libvirt domain has shared memory enabled and the filesystem target is
  exactly `shared`.
- **No clipboard sharing** — confirm Display is Spice (not VNC) and that
  `spice-vdagentd` is running inside the VM (`systemctl status spice-vdagentd`).
- **Tiny screen / no auto-resize** — Video must be virtio (or QXL), not Cirrus.
- **"command not found: nix-build"** after install — open a new shell so
  `/etc/profile.d/nix.sh` is sourced.
