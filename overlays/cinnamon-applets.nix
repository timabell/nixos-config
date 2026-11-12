# Third-party Cinnamon panel applets from linuxmint/cinnamon-spices-applets,
# pinned to one commit and installed into share/cinnamon/applets, which
# Cinnamon searches via XDG_DATA_DIRS. Only the listed applets are fetched
# (sparse checkout). To add one, append its uuid to `applets`.
# To bump: change `rev`, set `hash` to lib.fakeHash, rebuild, then paste
# the hash nix prints back in.

final: prev: {
  cinnamon-applets = prev.stdenvNoCC.mkDerivation rec {
    pname = "cinnamon-applets";
    version = "0-unstable-2026-11-11";

    applets = [
      "sysmonitor@orcus" # needs GTop: see sessionPath in modules/desktop.nix
      "pomodoro@gregfreeman.org"
    ];

    src = prev.fetchFromGitHub {
      owner = "linuxmint";
      repo = "cinnamon-spices-applets";
      rev = "4cc8cd5069489cea084575faa36f3f678669f937";
      sparseCheckout = applets;
      hash = "sha256-lhhwGIpSmREDKCbwizL3MWtDBrmGe2pQBrOz5KRaJgQ=";
    };

    # Pomodoro expects Debian paths and `play`/`python3` on PATH; its helper
    # imports `pipes`, which Python 3.13 removed.
    postPatch = ''
      p=pomodoro@gregfreeman.org/files/pomodoro@gregfreeman.org
      substituteInPlace $p/6.4/applet.js \
        --replace-fail /usr/bin/sox ${prev.sox}/bin/sox \
        --replace-fail '`python3 ' '`${prev.python3}/bin/python3 '
      substituteInPlace $p/6.4/sound.js \
        --replace-fail '`play ' '`${prev.sox}/bin/play '
      substituteInPlace $p/bin/kill-looping-sound.py \
        --replace-fail 'from pipes import quote' 'from shlex import quote'
    '';

    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/cinnamon/applets
      for uuid in $applets; do
        cp -r $uuid/files/$uuid $out/share/cinnamon/applets/
      done
    '';
  };
}
