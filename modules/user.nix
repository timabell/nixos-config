{ pkgs, ... }:

# Fork note: this is the single place the default user is defined. If
# you're reusing this config, change "tim" (and the description) to your
# own username here — nothing else references the name directly.

{
  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [ "wheel" "networkmanager" "audio" "docker" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
  };
}
