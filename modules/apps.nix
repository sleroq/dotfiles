{
  lib,
  config,
  pkgs,
  flakeRoot,
  ...
}:
with lib;
let
  cfg = config.sleroq.apps;
in
{
  options.sleroq.apps.enable = mkEnableOption "desktop apps and related services";

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      neovim
      wget
      curl
      # nvtopPackages.full
      powertop
    ];

    # For samba and other stuff
    services.gvfs.enable = true; # what is this and why do I need samba?

    # Steam remote play
    hardware.uinput.enable = true;

    programs = {
      nh = {
        enable = true;
        flake = flakeRoot;
      };
      neovim = {
        enable = true;
        defaultEditor = true;
      };

      steam = {
        enable = true;
        extest.enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        extraPackages = with pkgs; [
          gamescope
          mangohud
        ];
      };

      gamescope = {
        enable = true;
        # capSysNice = true; # breaks gamescope?
      };

      gamemode.enable = true;
      dconf.enable = true; # required by easyeffects and some other stuff
      fuse.userAllowOther = true; # why do I need this
      noisetorch = {
        enable = true;
        # TODO: On nixpkgs bumps, check for the PipeWire LADSPA fix and remove this
        # override AND the LADSPA_PATH setting below once fixed upstream:
        # https://github.com/noisetorch/NoiseTorch/issues/467
        package = pkgs.noisetorch.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace main.go --replace-fail \
              'f, err := ioutil.TempFile("", "librnnoise-*.so")' \
              'dir := os.Getenv("XDG_RUNTIME_DIR") + "/noisetorch"
            if err := os.MkdirAll(dir, 0700); err != nil {
              log.Fatalf("Could not create librnnoise directory: %v", err)
            }
            f, err := ioutil.TempFile(dir, "librnnoise-*.so")'
          '';
        });
      };
    };

    # Keep PipeWire's default LADSPA search paths while allowing NoiseTorch's runtime library.
    systemd.user.services.pipewire-pulse.environment.LADSPA_PATH =
      "%t/noisetorch:/usr/lib64/ladspa:/usr/lib/ladspa:${lib.getLib pkgs.pipewire}/lib";

    # services.ananicy = {
    #   enable = true;
    #   package = pkgs.ananicy-cpp;
    #   rulesProvider = pkgs.ananicy-cpp;
    #   extraRules = [
    #     {
    #       "name" = "gamescope";
    #       "nice" = -20;
    #     }
    #   ];
    # };
  };
}
