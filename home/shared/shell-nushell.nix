{
  lib,
  config,
  aliases,
  vars,
  ...
}:

let
  # Home Manager does not wire home.sessionVariables/home.sessionPath into Nushell
  # the same way it does for POSIX shells, so we bridge that here explicitly.
  exportToNuEnv =
    envVars:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        n: v:
        let
          replaceVars =
            varsIn: varsOut: value:
            "$env.${n} = ${
              if builtins.typeOf value == "string" then
                "\"${builtins.replaceStrings varsIn varsOut value}\""
              else
                toString value
            }";
          replaceVarPresets =
            value:
            builtins.replaceStrings
              [ "$\\{${n}:+:$${n}}\"" ]
              [
                ''" + (do { let x = ($env.${n}? | default ""); if $x == "" { "" } else { ":" + $x } }) | split row (char esep) | uniq''
              ]
              value;
        in
        lib.pipe v [
          (replaceVars [ "$HOME" "$USER" ] [ config.home.homeDirectory config.home.username ])
          replaceVarPresets
        ]
      ) envVars
    );

  esepDirListToList = var: ''
    "${var}" :{
      from_string: { |s|
        $s
        | default ""
        | split row (char esep)
        | where ($it | str length) > 0
        | path expand --no-symlink
      }
      to_string: { |v|
        $v
        | path expand --no-symlink
        | str join (char esep)
      }
    }
  '';

  paths =
    lib.concatLists [
      [ "${config.home.homeDirectory}/.nix-profile/bin" ]
      [ "/etc/profiles/per-user/${config.home.username}/bin" ]
      [ "/nix/var/nix/profiles/default/bin" ]
      [ "/run/current-system/sw/bin" ]
      [ "${config.home.homeDirectory}/.local/bin" ]
      config.home.sessionPath
      [ "${config.home.profileDirectory}/bin" ]
    ];

  binPaths = lib.pipe paths [
    (map (
      builtins.replaceStrings
        [ "$USER" "$HOME" "\${XDG_STATE_HOME}" ]
        [ config.home.username config.home.homeDirectory config.xdg.stateHome ]
    ))
    lib.unique
    (lib.concatMapStringsSep "\n          " (p: ''"${p}"''))
  ];
in
{
  enable = true;
  shellAliases = aliases;
  environmentVariables = vars;
  extraEnv = lib.mkBefore ''
    ${exportToNuEnv config.home.sessionVariables}
  '';
  extraConfig = lib.mkMerge [
    (lib.mkBefore ''
      $env.ENV_CONVERSIONS = {
        ${esepDirListToList "Path"}
        ${esepDirListToList "PATH"}
        ${esepDirListToList "TERMINFO_DIRS"}
        ${esepDirListToList "XDG_CONFIG_DIRS"}
        ${esepDirListToList "XDG_DATA_DIRS"}
        ${esepDirListToList "XCURSOR_PATH"}
      }

      const NU_LIB_DIRS = [
        ($nu.default-config-dir | path join 'scripts')
        ($nu.data-dir | path join 'completions')
      ]
    '')
    (lib.mkAfter ''
      let nix_paths = [
        ${binPaths}
      ]

      let existing_nix_paths = ($nix_paths | where { |p| $p | path exists })

      $env.PATH = ($env.PATH | split row (char esep) | where { |p| $p not-in $existing_nix_paths } | append $existing_nix_paths)
    '')
  ];
  settings = {
    show_banner = false;
    buffer_editor = "nvim";
    history = {
      max_size = 1100000;
      sync_on_enter = true;
      file_format = "sqlite";
      isolation = true;
    };
  };
}
