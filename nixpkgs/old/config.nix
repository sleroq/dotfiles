{ pkgs }:

let
  extraOutputsToInstall = [ "man" "doc" "inhfo" "icons" ];
in
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
      export XDG_DATA_DIRS="$HOME/.nix-profile/share:$XDG_DATA_DIRS"
      export MANPATH="$HOME/.nix-profile/share/man:/nix/var/nix/profiles/default/share/man:$MANPATH"
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
      ];
      inherit extraOutputsToInstall;
    };

    toolsEnv = pkgs.buildEnv {
      name = "tools-packages";
      paths = [
        pavucontrol
        helvum
        stow
        lxappearance
      ];
      inherit extraOutputsToInstall;
    };

    appsEnv = pkgs.buildEnv {
      name = "apps-packages";
      paths = [
        firefox
        chromium
        tdesktop
        discord
        github-desktop

        lf

        tmux

        gimp
        mpv
      ];
      inherit extraOutputsToInstall;
    };

    waylandEnv = pkgs.buildEnv {
      name = "wayland-packages";
      paths = [
        slurp
        grim
        # sway -- won't work :c
        waybar
      ];
      inherit extraOutputsToInstall;
    };

    devEnv = pkgs.buildEnv {
      name = "development-packages";
      paths = [
        nixfmt
      ];
      inherit extraOutputsToInstall;
    };

    # customEnv = pkgs: {
    #   my-lf = callPackage ./packages/my-lf {  };
    # };
  };
}
