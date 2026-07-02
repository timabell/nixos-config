{ pkgs, ... }:

# Baseline Python. Split into its own importable module because python
# tends to bleed into general user tooling. The dev VM imports it (mise
# plugins need it); on bare-metal hosts the import is commented out as an
# experiment to see whether the base machine can live without it.

{
  environment.systemPackages = [ pkgs.python3 ];
}
