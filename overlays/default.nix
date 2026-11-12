# Overlays change what `pkgs.<name>` means for a machine: they add packages
# that aren't in nixpkgs, or swap a stable package for a newer or patched
# build. A machine only gets the overlays listed for it in flake.nix.
#
# Each file holds one overlay, with the reason for it in its header comment.

{ nixpkgs-unstable, gitopolis, disk-hog-backup }:

{
  # Not in nixpkgs.
  gitopolisOverlay = import ./gitopolis.nix { inherit gitopolis; };
  diskHogBackupOverlay = import ./disk-hog-backup.nix { inherit disk-hog-backup; };
  schemaExplorerOverlay = import ./schema-explorer.nix;
  beadsTuiOverlay = import ./beads-tui.nix;
  cinnamonAppletsOverlay = import ./cinnamon-applets.nix;

  # Patched builds.
  lazydockerProfilesOverlay = import ./lazydocker.nix;

  # Newer versions from nixpkgs-unstable.
  fromUnstableOverlay = import ./from-unstable.nix { inherit nixpkgs-unstable; };
}
