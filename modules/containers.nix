{ ... }:

# Docker engine. Safe enough for bare metal under the fleet's dev-sandbox
# policy, and needed inside the dev VM too — so it lives in its own
# module that both the common host set and the devvm import.

{
  virtualisation.docker.enable = true;
}
