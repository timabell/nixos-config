# Shutter's Hard Shadow plugin always opens on SouthEast and has nowhere
# to remember a choice; default it to Center, the one Tim always uses.

final: prev: {
  shutter = prev.shutter.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace share/shutter/resources/system/plugins/perl/spshadow/spshadow \
        --replace-fail '$direction_combo->set_active( 8 );' '$direction_combo->set_active( 4 );'
    '';
  });
}
