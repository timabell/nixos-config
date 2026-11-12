# Third-party Cinnamon panel applets from linuxmint/cinnamon-spices-applets,
# pinned to one commit and installed into share/cinnamon/applets, which
# Cinnamon searches via XDG_DATA_DIRS. Only the listed applets are fetched
# (sparse checkout).
#
# Spices are written for Mint: they assume /usr/bin, tools on PATH, and a
# writable applet folder. None of that holds here (the folder is in the
# read-only store). So when adding an applet, or bumping `rev`, read its
# source and grep for anything that runs a command or names a path:
#   grep -rnE 'spawn|Subprocess|/usr/|/bin/|python|make' <uuid>/files/<uuid>/
# and patch or check each hit. Bare command names are fine if the command
# is on the system PATH (e.g. xrandr and which for brightness-and-gamma).
# Also read the applet's README "Dependencies" section. Grep misses
# runtime-only failures, like a `#!/bin/bash` script (no /bin/bash here);
# Looking Glass (Ctrl+Alt+L) shows an applet's load errors.
#
# Version folders: Cinnamon loads an applet's newest <version>/ subfolder
# that is <= the running Cinnamon version. The patches below target the
# folder used by Cinnamon 6.4 (nixpkgs 26.05). When Cinnamon is upgraded,
# check which folder each applet now loads and move the patches.
# --replace-fail won't catch this, since the old folder still matches.
# (brightness-and-gamma has a 6.6/ folder that also wants xsct + geo.py.)
#
# To bump: change `rev`, set `hash` to lib.fakeHash, rebuild, then paste
# the hash nix prints back in. A failing --replace-fail means upstream
# changed patched code: re-read it and redo that patch.

final: prev: {
  cinnamon-applets = prev.stdenv.mkDerivation rec {
    pname = "cinnamon-applets";
    version = "0-unstable-2026-11-11";

    applets = [
      "sysmonitor@orcus" # needs GTop: see sessionPath in modules/desktop.nix
      "pomodoro@gregfreeman.org"
      "auto-dark-light@gihaume"
      "brightness-and-gamma-applet@cardsurf"
    ];

    src = prev.fetchFromGitHub {
      owner = "linuxmint";
      repo = "cinnamon-spices-applets";
      rev = "4cc8cd5069489cea084575faa36f3f678669f937";
      sparseCheckout = applets;
      hash = "sha256-dcLUeEo6H5gIfv0XhXd4ryKyI+8t1NbiJdv3xeoknO4=";
    };

    postPatch = ''
      # Pomodoro (all found by the grep above; its README asks for
      # `apt install sox`):
      #  - /usr/bin/sox only decides whether to nag "install sox".
      #  - `play` (sox) and `python3` aren't on the system PATH; without
      #    them sounds are silent and the looping tick can't be stopped.
      #  - The tick-killer imports `pipes`, removed in Python 3.13
      #    (PEP 594); shlex.quote is the same function.
      p=pomodoro@gregfreeman.org/files/pomodoro@gregfreeman.org
      substituteInPlace $p/6.4/applet.js \
        --replace-fail /usr/bin/sox ${prev.sox}/bin/sox \
        --replace-fail '`python3 ' '`${prev.python3}/bin/python3 '
      substituteInPlace $p/6.4/sound.js \
        --replace-fail '`play ' '`${prev.sox}/bin/play '
      substituteInPlace $p/bin/kill-looping-sound.py \
        --replace-fail 'from pipes import quote' 'from shlex import quote'

      # auto-dark-light: its README lists make + g++ as dependencies, which
      # led to the constructor in time_change_listener.js. On every load it
      # refuses to start without make/g++, then runs `make` to build its C++
      # clock-change helper into its own (here read-only) folder. buildPhase
      # builds the helper instead; skip the check and turn the compile into
      # a no-op. The helper itself only watches a timerfd for clock changes.
      substituteInPlace auto-dark-light@gihaume/files/auto-dark-light@gihaume/5.8/lib/time_change_listener/time_change_listener.js \
        --replace-fail "if (!(GLib.find_program_in_path('make') && GLib.find_program_in_path('g++')))" "if (false)" \
        --replace-fail "argv: ['make', '-C', path]," "argv: ['${prev.coreutils}/bin/true'],"
    '';

    buildPhase = ''
      make -C auto-dark-light@gihaume/files/auto-dark-light@gihaume/5.8/lib/time_change_listener
      rm -r auto-dark-light@gihaume/files/auto-dark-light@gihaume/5.8/lib/time_change_listener/build
    '';

    installPhase = ''
      mkdir -p $out/share/cinnamon/applets
      for uuid in $applets; do
        cp -r $uuid/files/$uuid $out/share/cinnamon/applets/
      done
    '';
  };
}
