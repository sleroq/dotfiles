{ lib
, dwl
, makeWrapper, symlinkJoin, writeShellScriptBin
, extraSessionCommands ? "", dbus
, withGtkWrapper ? false, wrapGAppsHook, gdk-pixbuf, glib, gtk3
, extraOptions ? [] # E.g.: [ "-v" ]
, enableXWayland ? true
, dbusSupport ? true
, postPatch ? ""
, patches ? [ ]
}:

let
  dwl-wrapped = (dwl.overrideAttrs(finalAttrs: previousAttrs: {
      inherit enableXWayland postPatch patches;
    }));
  baseWrapper = writeShellScriptBin dwl-wrapped.meta.mainProgram ''
     set -o errexit
     if [ ! "$_DWL_WRAPPER_ALREADY_EXECUTED" ]; then
       export XDG_CURRENT_DESKTOP=${dwl-wrapped.meta.mainProgram}
       ${extraSessionCommands}
       export _DWL_WRAPPER_ALREADY_EXECUTED=1
     fi
     if [ "$DBUS_SESSION_BUS_ADDRESS" ]; then
       export DBUS_SESSION_BUS_ADDRESS
       exec ${lib.getExe dwl-wrapped} "$@"
     else
       exec ${lib.optionalString dbusSupport "${dbus}/bin/dbus-run-session"} ${lib.getExe dwl-wrapped} "$@"
     fi
   '';
in symlinkJoin rec {
  inherit (dwl-wrapped) version pname;
  name = "${pname}-${version}";

  paths = [baseWrapper dwl-wrapped ];

  strictDeps = false;
  nativeBuildInputs = [ makeWrapper ]
    ++ (lib.optional withGtkWrapper wrapGAppsHook);

  buildInputs = lib.optionals withGtkWrapper [ gdk-pixbuf glib gtk3 ];

  # We want to run wrapProgram manually
  dontWrapGApps = true;

  postBuild = ''
    ${lib.optionalString withGtkWrapper "gappsWrapperArgsHook"}

    wrapProgram $out/bin/${dwl-wrapped.meta.mainProgram} \
      ${lib.optionalString withGtkWrapper ''"''${gappsWrapperArgs[@]}"''} \
      ${lib.optionalString (extraOptions != []) "${lib.concatMapStrings (x: " --add-flags " + x) extraOptions}"}
  '';

  passthru = {
    providedSessions = [ dwl-wrapped.meta.mainProgram ];
  };

  # FIXME: Something isn't right here
  meta = {
    inherit (dwl-wrapped) meta;
  };
  # inherit (dwl-wrapped) meta; # This does not work for some reason
}
