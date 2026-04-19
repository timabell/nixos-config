{ pkgs, ... }:

{
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    # syncthing
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 21027 ];
  };

  # syncthing
  services.syncthing = {
    enable = true;
    user = "tim";
    dataDir = "/home/tim";
  };

  # tailscale mesh vpn
  services.tailscale.enable = true;

  # ssh server
  services.openssh.enable = true;

  # firewall gui
  programs.firejail.enable = false; # gufw is gtk, use nftables directly

  environment.systemPackages = with pkgs; [
    mosh
    wakeonlan
    openvpn
  ];
}
