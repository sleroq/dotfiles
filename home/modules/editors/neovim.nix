{
  config,
  pkgs,
  opts,
  lib,
  inputs',
  ...
}:
let
  cfg = config.sleroq.neovim;
  neovim = import ../../../lib/neovim.nix {
    inherit pkgs inputs';
  };
in
{
  options.sleroq.neovim = {
    enable = lib.mkEnableOption "the shared Neovim environment";
    enableNeovide = lib.mkEnableOption "Neovide";
    default = lib.mkEnableOption "Neovim as the default editor";
  };

  config = lib.mkIf cfg.enable {
    home.packages = neovim.packages ++ [ pkgs.obsidian-neovide ];

    home.sessionVariables = lib.mkIf cfg.default {
      EDITOR = "nvim";
    };

    programs.neovide = lib.mkIf cfg.enableNeovide {
      enable = true;
      settings = { };
    };

    home.activation.neovim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -L "$HOME/.config/nvim/init.lua" ]; then
        case "$(readlink "$HOME/.config/nvim/init.lua")" in
          /nix/store/*-home-manager-files/.config/nvim/init.lua)
            $DRY_RUN_CMD rm $VERBOSE_ARG "$HOME/.config/nvim/init.lua"
            ;;
        esac
      fi

      if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
        $DRY_RUN_CMD rmdir $VERBOSE_ARG "$HOME/.config/nvim"
      fi

      $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
          ${opts.realConfigs}/nvim "$HOME/.config/nvim"
    '';
  };
}
