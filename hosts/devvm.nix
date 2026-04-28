{ pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  # Boot/fs config matching the qcow image produced by nixos-generators
  # (single ext4 root labeled "nixos", grub on /dev/vda). Declared here so
  # that `nixos-rebuild switch --flake .#devvm` works in-place inside the
  # running VM, not only during image build.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };
  boot.growPartition = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.timeout = 0;

  # 80 GiB cap on the qcow2. Sparse: actual host disk usage grows as the
  # guest writes, so this is a cap, not an up-front cost.
  virtualisation.diskSize = 80 * 1024;

  networking.hostName = "devvm";

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "docker" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
  };

  # XFCE desktop (lightweight alternative to Cinnamon)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.displayManager.defaultSession = "xfce";

  services.xserver.xkb.layout = "gb";
  console.keyMap = "uk";

  # SPICE: bidirectional clipboard + display auto-resize
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  # sound
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.zsh.enable = true;

  # network: NetworkManager for the GUI applet, firewall on (outbound-only by default)
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # virtiofs shared folder from host. The libvirt domain must define a filesystem
  # with target tag "shared" pointing at the host directory you want exposed.
  # nofail keeps the VM bootable even when the share isn't attached.
  fileSystems."/home/tim/work" = {
    device = "shared";
    fsType = "virtiofs";
    options = [ "nofail" ];
  };

  # fonts
  fonts.packages = with pkgs; [ jetbrains-mono ];

  # allow IDEs that aren't free-licensed
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "jetbrains-toolbox"
      "vscode"
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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

  system.stateVersion = "25.05";
}
