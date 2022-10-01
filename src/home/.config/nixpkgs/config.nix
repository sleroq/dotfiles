{
  allowUnfree = true;
  packageOverrides = pkgs: with pkgs; rec {
    myProfile = writeText "my-profile" ''
      path+=(
        "$HOME/.nix-profile/bin"
        "/nix/var/nix/profiles/default/bin"
        "/sbin"
        "/bin"
        "/usr/sbin"
        "/usr/bin"
      )
      export XDG_DATA_DIRS="$HOME/.nix-profile/share:$HOME/.share:/usr/local/share/:/usr/share/"
      export MANPATH="$HOME/.nix-profile/share/man:/nix/var/nix/profiles/default/share/man:/usr/share/man"
      export LD_LIBRARY_PATH="$HOME/.nix-profile/lib:$LD_LIBRARY_PATH"
    '';

    myPackages = pkgs.buildEnv {
      name = "my-packages";
      paths = [
        (runCommand "profile" {} ''
          mkdir -p $out/etc/profile.d
          cp ${myProfile} $out/etc/profile.d/my-profile.zsh
        '')
        jq
        neofetch
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };

    toolsEnv = pkgs.buildEnv {
      name = "tools-packages";
      paths = [
        pavucontrol
        helvum
        stow
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };

    appsEnv = pkgs.buildEnv {
      name = "apps-packages";
      paths = [
        firefox
        chromium
        tdesktop
        discord
        github-desktop
        syncthing
        lf
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };

    waylandEnv = pkgs.buildEnv {
      name = "wayland-packages";
      paths = [
        slurp
        grim
        # sway -- won't work :c
        waybar
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };

    devEnv = pkgs.buildEnv {
      name = "development-packages";
      paths = [
        nixfmt
        niv
        go
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };

    # customEnv = pkgs: {
    #   my-lf = callPackage ./packages/my-lf {  };
    # };
  };
}
