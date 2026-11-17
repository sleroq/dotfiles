{
  lib,
  config,
  opts,
  ...
}:
{
  options.myHome.programs.herdr.enable = lib.mkEnableOption "Herdr configuration";

  config = lib.mkIf config.myHome.programs.herdr.enable {
    xdg.configFile."herdr-core/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-core/config.toml";
    xdg.configFile."herdr-app/layouts/sidebar-right.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/layouts/sidebar-right.json";
    xdg.configFile."herdr-app/layouts/teto98.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/layouts/teto98.json";
    xdg.configFile."herdr-app/layouts/teto98.png".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/layouts/teto98.png";
    xdg.configFile."herdr-app/mods/teto98/main.js".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98/main.js";
    xdg.configFile."herdr-app/mods/teto98/mod.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98/mod.json";
    xdg.configFile."herdr-app/mods/teto98/teto.png".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98/teto.png";
    xdg.configFile."herdr-app/mods/teto98/teto-walk.gif".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98/teto-walk.gif";
    xdg.configFile."herdr-app/mods/teto98-toast/main.js".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98-toast/main.js";
    xdg.configFile."herdr-app/mods/teto98-toast/mod.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98-toast/mod.json";
    xdg.configFile."herdr-app/mods/teto98-menu/main.js".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98-menu/main.js";
    xdg.configFile."herdr-app/mods/teto98-menu/mod.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98-menu/mod.json";
    xdg.configFile."herdr-app/mods/teto98-taskbar".source =
      config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/herdr-app/mods/teto98-taskbar";
  };
}
