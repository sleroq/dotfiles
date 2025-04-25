{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.btop.catppuccin;
  
  themeVariants = {
    latte = "catppuccin_latte";
    frappe = "catppuccin_frappe";
    macchiato = "catppuccin_macchiato";
    mocha = "catppuccin_mocha";
  };
  
  catppuccinBtopRepo = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "btop";
    rev = "main";
    sha256 = "sha256-mEGZwScVPWGu+Vbtddc/sJ+mNdD2kKienGZVUcTSl+c=";
  };
  
in {
  options.programs.btop.catppuccin = {
    enable = mkEnableOption "Catppuccin theme for btop";
    
    variant = mkOption {
      type = types.enum (attrNames themeVariants);
      default = "macchiato";
      description = "Catppuccin theme variant to use (latte, frappe, macchiato, or mocha)";
    };
  };
  
  config = mkIf cfg.enable {
    programs.btop.enable = true;
    
    # xdg.configFile."btop/themes/${themeVariants.${cfg.variant}}.theme".source = 
    #   "${catppuccinBtopRepo}/themes/${themeVariants.${cfg.variant}}.theme";
    
    programs.btop.settings = {
      color_theme = "adapta"; # themeVariants.${cfg.variant};
    };
  };
}
