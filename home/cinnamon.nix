{ config, pkgs, lib, ... }:

# Deterministic Cinnamon panel + settings for the desktop fleet (cog, x15;
# both run modules/desktop.nix). Captured from `dconf dump /org/cinnamon/`
# on cog and frozen here so the panel reconciles on every rebuild and never
# needs configuring through the GUI.
#
# Two entries from the dump are deliberately omitted:
#   - command-history                     (transient run-dialog state)
#   - plugins/color night-light-last-coordinates
#                                         (device GPS; this repo is public)
#
# Cinnamon splits its state across two stores. The panel layout and simple
# settings live in dconf (below, via dconf.settings). Each applet's own
# settings live in a writable "spice" JSON that Cinnamon regenerates from
# its schema on upgrade — so the calendar clock format is reconciled into
# that live file by an activation script rather than symlinked read-only
# (which Cinnamon would clobber on the next upgrade).

let
  calendarFormat = "📅 %a %e %b %Y 🕓 %H:%M:%S";

  # An applet's instance id (the trailing number in its enabled-applets
  # entry) is also its spice-settings filename, so pin it once here and use
  # it in both places — the enabled-applets entry below and the JSON path
  # the activation script targets — so the two can't drift.
  calendarInstanceId = "13";
  calendarSettings =
    "${config.xdg.configHome}/cinnamon/spices/calendar@cinnamon.org/${calendarInstanceId}.json";
in
{
  dconf.settings = {
    "org/cinnamon" = {
      enabled-applets = [
        "panel1:left:0:menu@cinnamon.org:0"
        "panel1:left:1:separator@cinnamon.org:1"
        "panel1:left:2:grouped-window-list@cinnamon.org:2"
        "panel1:right:0:systray@cinnamon.org:3"
        "panel1:right:1:xapp-status@cinnamon.org:4"
        "panel1:right:2:notifications@cinnamon.org:5"
        "panel1:right:3:printers@cinnamon.org:6"
        "panel1:right:4:removable-drives@cinnamon.org:7"
        "panel1:right:5:keyboard@cinnamon.org:8"
        "panel1:right:6:favorites@cinnamon.org:9"
        "panel1:right:7:network@cinnamon.org:10"
        "panel1:right:8:sound@cinnamon.org:11"
        "panel1:right:9:power@cinnamon.org:12"
        "panel1:right:10:calendar@cinnamon.org:${calendarInstanceId}"
        "panel1:right:11:cornerbar@cinnamon.org:14"
      ];
      next-applet-id = 15;
    };

    "org/cinnamon/desktop/interface" = {
      toolkit-accessibility = false;
    };

    "org/cinnamon/desktop/sound" = {
      event-sounds = false;
    };

    "org/cinnamon/settings-daemon/peripherals/keyboard" = {
      numlock-state = "off";
    };

    "org/cinnamon/settings-daemon/plugins/power" = {
      button-power = "interactive";
      lid-close-ac-action = "suspend";
      lid-close-battery-action = "suspend";
      sleep-display-ac = 1800;
      sleep-display-battery = 1800;
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-battery-timeout = 0;
    };
  };

  # Reconcile only the two value keys we care about. __md5__ is a hash of the
  # applet's settings-schema.json that Cinnamon checks on load; if it no
  # longer matches, Cinnamon rebuilds the file from the schema and drops any
  # values in it. So touch only the `value` fields and leave __md5__ (and the
  # schema-derived structure) alone, keeping the hash valid and our edits
  # intact. Runs every activation; if the spice file doesn't exist yet (first
  # login, before Cinnamon has created it), skip and catch it next rebuild.
  home.activation.cinnamonCalendarFormat =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f ${lib.escapeShellArg calendarSettings} ]; then
        run ${pkgs.jq}/bin/jq \
          --arg fmt ${lib.escapeShellArg calendarFormat} \
          '.["use-custom-format"].value = true | .["custom-format"].value = $fmt' \
          ${lib.escapeShellArg calendarSettings} \
          > ${lib.escapeShellArg "${calendarSettings}.hm-tmp"} \
          && run mv ${lib.escapeShellArg "${calendarSettings}.hm-tmp"} \
               ${lib.escapeShellArg calendarSettings}
      fi
    '';
}
