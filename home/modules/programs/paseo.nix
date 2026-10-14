{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  pi = self.inputs.pi.packages.${system}.default;
  bin = "${config.home.profileDirectory}/bin";
  baseline = (pkgs.formats.json { }).generate "paseo-config.json" (
    import ../../../modules/paseo/config.nix {
      inherit lib;
      listen = "127.0.0.1:6767";
      commands = {
        pi = [ "${bin}/pi-direnv" ];
        opencode = [ "${bin}/opencode" ];
        codex = [ "${bin}/codex" ];
      };
    }
  );
  piDirenv = pkgs.writeShellScriptBin "pi-direnv" ''
    export PI_FFF_MODE=override
    exec ${pkgs.direnv}/bin/direnv exec "$PWD" ${pi}/bin/pi "$@"
  '';
in
{
  options.myHome.programs.paseo.enable = lib.mkEnableOption "shared Paseo settings";
  config = lib.mkIf config.myHome.programs.paseo.enable {
    home.packages = [
      piDirenv
      self.inputs.llm-agents.packages.${system}.codex
    ];
    home.activation.paseoConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.nodejs_24}/bin/node ${../../../modules/paseo/config.mjs} ${baseline} "$HOME/.paseo/config.json"
    '';
  };
}
