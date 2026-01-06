{ inputs', pkgs, lib, config, opts, ... }:

let
  cfg = config.myHome.gaming;
in
{
  options.myHome.gaming = {
    osu = {
      enable = lib.mkEnableOption "osu! lazer";
      enableTearing = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tearing for osu!";
      };
    };

    etterna.enable = lib.mkEnableOption "etterna";

    minecraft.enable = lib.mkEnableOption "osu! lazer";
  };

  config = lib.mkMerge [
    {
      home.packages = [ pkgs.protonup-qt ];
    }

    (lib.mkIf cfg.osu.enable {
      home.packages = with inputs'.nix-gaming.packages; [
        # (osu-lazer-bin.override { releaseStream = "tachyon"; })
        (osu-lazer-bin.override { releaseStream = "lazer"; })
        osu-lazer-bin
        pkgs.opentabletdriver
      ];
    })
    
    (lib.mkIf cfg.etterna.enable { home.packages = [ pkgs.etterna ]; })

    (lib.mkIf cfg.minecraft.enable {
      home.activation.waywall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
            ${opts.realConfigs}/waywall $HOME/.config
      '';

      home.packages = [
        pkgs.graalvmPackages.graalvm-oracle

        (pkgs.prismlauncher.override {
          additionalLibs = with pkgs; [
            # Required for ninjabot
            fontconfig
            libx11

            xorg.libXtst
            libxkbcommon
            libxt
            libxinerama # unsure
            libdecor # unsure

            # waywall deps
            libGL
            libspng
            libxkbcommon
            luajit
            wayland
            wayland-protocols
            xorg.libxcb
            xwayland

            (glfw.override { withMinecraftPatch = true; })
              # .overrideAttrs (old: {
              #   pname = "glfw-waywall";
              #   patches = [
              #     (pkgs.fetchpatch {
              #       url = "https://raw.githubusercontent.com/tesselslate/waywall/be3e018bb5f7c25610da73cc320233a26dfce948/contrib/glfw.patch";
              #       sha256 = "8Sho5Yoj/FpV7utWz3aCXNvJKwwJ3ZA3qf1m2WNxm5M=";
              #     })
              #   ];
              # }))
          ];
          additionalPrograms = [
            (pkgs.waywall.overrideAttrs (old: {
              src = pkgs.fetchFromGitHub {
                owner = "tesselslate";
                repo = "waywall";
                rev = "ed76c2b605d19905617d9060536e980fd49410bf";
                hash = "sha256-ev/A5ksqmWz6hpwUIoxg2k9BwzE4BNCZO4tpXq790zo=";
              };
            }))
          ];
          jdks = [ pkgs.jdk21 pkgs.graalvmPackages.graalvm-oracle ];
        })
      ];
    })
  ];
}
