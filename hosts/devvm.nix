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

  # sound
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.zsh.enable = true;

  # NetworkManager replaces the base's plain DHCP for desktop UX.
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkForce false;
  networking.firewall.enable = true;

  # fonts
  fonts.packages = with pkgs; [ jetbrains-mono ];

  # allow IDEs that aren't free-licensed
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "jetbrains-toolbox"
      "vscode"
    ];

  environment.systemPackages = with pkgs; [
    # IDEs
    jetbrains-toolbox
    vscode

    # browser (for docs/auth flows inside the VM)
    firefox

    # desktop conveniences
    xclip
    pavucontrol
  ];
}
