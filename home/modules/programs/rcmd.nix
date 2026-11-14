{
  lib,
  config,
  opts,
  ...
}:

{
  options.myHome.programs.rcmd.enable = lib.mkEnableOption "rcmd configuration";

  config = lib.mkIf config.myHome.programs.rcmd.enable {
    xdg.configFile."rcmd/config.yaml".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/rcmd/config.yaml";
  };
}
