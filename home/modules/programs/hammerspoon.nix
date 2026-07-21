{
  lib,
  config,
  ...
}:

let
  cfg = config.myHome.programs.hammerspoon;
in
{
  options.myHome.programs.hammerspoon.enable = lib.mkEnableOption "Hammerspoon configuration";

  config = lib.mkIf cfg.enable {
    home.file.".hammerspoon/init.lua".source = ../../config/hammerspoon/init.lua;
  };
}
