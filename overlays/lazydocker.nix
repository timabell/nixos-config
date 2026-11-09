# Upstream lazydocker doesn't understand docker-compose profiles
# (https://github.com/jesseduffield/lazydocker/issues/423). Pulled from
# timabell/lazydocker @ feat/docker-compose-profiles, a from-scratch
# implementation on top of master (see that repo's
# docs/adr/0001-docker-compose-profile-support.md). Upstream
# vendorHash is null (deps are vendored), so overriding src is enough.

final: prev: {
  lazydocker = prev.lazydocker.overrideAttrs (_: {
    src = prev.fetchFromGitHub {
      owner = "timabell";
      repo = "lazydocker";
      rev = "1f035a8d6d318c84e8d7ec47cb3d9ba3a1b5f961";
      hash = "sha256-gxxNYclOc7KvZwt54Y0S4sUjq3xNxzuZdtRkmzTgWuk=";
    };
  });
}
