{ pkgs, lib, ... }:

# Full devvm config — XFCE + IDEs. Layered on top of devvm-base. Applied
# via `nixos-rebuild switch --flake .#devvm` from inside a running
# devvm-base VM (fast: fetches from cache.nixos.org) rather than via a
# fresh image build (slow: cptofs).
#
# Host-side concerns (e.g. virtiofs shared folders) are deliberately left
# out — mount them ad-hoc inside the VM with `sudo mount -t virtiofs
# <tag> <mountpoint>` when you want one. Keeps this config portable
# across "with/without share" and different share tags.

{
  imports = [
    ./devvm-base.nix
  ];

  # Override the image baseName for full-image rebuilds (rare path).
  image.baseName = lib.mkForce "devvm";

  users.users.tim.shell = pkgs.zsh;
  users.users.tim.extraGroups = [ "networkmanager" "audio" "video" "docker" ];

  # XFCE desktop (lightweight alternative to Cinnamon)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.desktopManager.xfce.enableScreensaver = false;
  services.displayManager.defaultSession = "xfce";
  services.xserver.xkb.layout = "gb";

  # No screen blanking, no DPMS standby/suspend/off — this is a VM, the
  # host already handles screen lock for the human.
  services.xserver.serverFlagsSection = ''
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
  '';

  # SPICE: bidirectional clipboard + display auto-resize
  services.spice-vdagentd.enable = true;

  # spice-vdagent hardcodes a search for /dev/dri/card0; under UEFI the
  # qxl/virtio-gpu DRM device often shows up as card1, breaking both
  # clipboard and auto-resize. Symlink whichever virtio/QXL DRM card we
  # have to dri/card0.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ATTRS{vendor}=="0x1af4", ATTRS{device}=="0x1050", SYMLINK+="dri/card0"
    SUBSYSTEM=="drm", ATTRS{vendor}=="0x1b36", ATTRS{device}=="0x0100", SYMLINK+="dri/card0"
  '';

  # FHS shim for prebuilt binaries (mise-installed node, .NET, Bun, etc.)
  # Without this, prebuilt linux-x64 binaries can't find their dynamic
  # linker (/lib64/ld-linux-x86-64.so.2 doesn't exist on NixOS) and
  # either fail or fall back to source builds.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib   # libstdc++ — modern node, .NET, anything C++
    zlib               # very commonly linked
    openssl            # node's native modules, .NET, etc.
    icu                # node's intl support
    libxml2
    libuuid
    glib
  ];

  # Auto-mount the virtiofs share that dev-vm-install.sh attaches.
  # Tag "work" matches SHARE_TAG in the host script. nofail keeps the VM
  # bootable if a future variant runs without the share attached.
  fileSystems."/home/tim/work" = {
    device = "work";
    fsType = "virtiofs";
    options = [ "nofail" ];
  };

  # 8 GiB swapfile. The qcow2 ships swapless; npm installs of big
  # dep trees can blow past 16 GiB RAM and trigger OOM-kills, taking
  # the X session with them. Place at root since /swap doesn't exist
  # on the image's flat ext4 layout (unlike x15 which has a btrfs
  # subvolume).
  swapDevices = [{
    device = "/swapfile";
    size = 8192;
  }];

  # sound
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.zsh.enable = true;

  # GnuPG: needed by mise (upstream signature verification) and by gopass
  # (decrypts the password store with the user's private key). The
  # programs.gnupg.agent option installs gnupg, sets up gpg-agent as a
  # user service, and wires in a pinentry — without one, decryption
  # fails with "No pinentry". pinentry-curses keeps things terminal-only
  # so gopass works the same over SSH and inside an XFCE terminal.
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  # NetworkManager replaces the base's plain DHCP for desktop UX.
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkForce false;
  networking.firewall.enable = true;

  # fonts
  fonts.packages = with pkgs; [ jetbrains-mono ];

  # allow IDEs that aren't free-licensed
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "rider"
      "vscode"
    ];

  environment.systemPackages = with pkgs; [
    # IDEs
    jetbrains.rider
    vscode

    # browser (for docs/auth flows inside the VM)
    firefox

    # desktop conveniences
    xclip
    pavucontrol

    # node + npm. VM-only — not in modules/development.nix because npm
    # is not safe to run on primary hosts. Per-project versions via a
    # flake.nix + direnv inside individual repos.
    nodejs_24

    # direnv + nix-direnv: per-project dev shells via flake.nix +
    # `.envrc` containing `use flake`. VM-only because auto-loading
    # repo-local config (even with `direnv allow`) is one more
    # supply-chain edge we don't want on the primary host.
    direnv
    nix-direnv

    # mise — per-project runtime version manager. Hybrid model: nix
    # provides system-level node/npm/claude/etc., mise provides
    # exact-version-match for client repos with a .tool-versions or
    # .nvmrc. VM-only for supply-chain reasons; mise pulls upstream
    # prebuilts and we don't want those touching the host.
    mise
    python3       # required by some mise plugins

    # Anthropic's Claude Code CLI. VM-only — agents run inside the VM,
    # never on the host. Pulled from unstable via overlay in flake.nix
    # so we get current releases (claude-code updates weekly).
    claude-code

    # .env password manager https://github.com/gopasspw/gopass
    gopass
  ];
}
