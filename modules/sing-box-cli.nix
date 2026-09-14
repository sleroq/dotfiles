{
  lib,
  pkgs,
  cfg,
  namedSources,
  hasSystemd,
  configTemplate,
  staticOutbounds,
  workingDirectory,
  directBypassMarkDecimal,
}:
let
  json = pkgs.formats.json { };
  subscription = cfg.subscription;
  declaredStore = json.generate "sing-box-subscriptions.json" {
    subscriptions = map (source: {
      id = source.name;
      url_file = source.urlFile;
      inherit (source) prefix;
      disabled = !source.enable;
      auto = source.autoSelect;
      include_tags = source.includeTags;
      exclude_tags = source.excludeTags;
      include_servers = source.includeServers;
      exclude_servers = source.excludeServers;
    }) namedSources;
  };
  # TODO: This should be extracted into module in the sb repository
  settings = json.generate "sb-config.json" (
    {
      template_file = toString configTemplate;
      static_outbounds_file = toString staticOutbounds;
      state_dir = workingDirectory;
      api_url = "http://${subscription.apiAddress}";
      test_url = subscription.testURL;
      test_interval = subscription.testInterval;
      tolerance = subscription.tolerance;
      sing_box = "${cfg.package}/bin/sing-box";
      converter = "${subscription.package}/bin/sing-box-sub";
      exclude_protocols = subscription.excludeProtocols;
      exclude_node_names = subscription.excludeNodeNames;
      overrides_file = "${workingDirectory}/overrides.json";
      stores =
        lib.optional (namedSources != [ ]) {
          name = "nix";
          path = toString declaredStore;
          writable = false;
        }
        ++ subscription.stores;
      restart_command =
        if hasSystemd then
          [
            "${pkgs.systemd}/bin/systemctl"
            "restart"
            "sing-box.service"
          ]
        else
          [
            "/bin/launchctl"
            "kickstart"
            "-k"
            "system/org.nixos.sing-box"
          ];
    }
    // lib.optionalAttrs hasSystemd {
      routing_mark = directBypassMarkDecimal;
    }
    // lib.optionalAttrs (cfg.extraOutboundsFile != null) {
      extra_outbounds_file = cfg.extraOutboundsFile;
    }
    // lib.optionalAttrs (!subscription.enable && cfg.outboundsFile != null) {
      legacy_outbounds_file = cfg.outboundsFile;
    }
  );
  sb = pkgs.writeShellScriptBin "sb" ''
    exec ${cfg.cliPackage}/bin/sb --config ${settings} "$@"
  '';
  updateSubscription = pkgs.writeShellScript "sing-box-update" ''
    exec ${sb}/bin/sb update
  '';
in
{
  inherit sb settings updateSubscription;
}
