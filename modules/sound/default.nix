{ lib, config, ... }:
with lib;
let
  cfg = config.sleroq.sound;
in
{
  options.sleroq.sound.enable = mkEnableOption "PipeWire with rtkit";

  config = mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;

      extraConfig.pipewire."92-stable-quantum" = {
        "context.properties" = {
          "default.clock.min-quantum" = 256;
        };
      };
    };
  };
}
