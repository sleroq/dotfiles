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
      export XDG_DATA_DIRS="$HOME/.nix-profile/share:$HOME/.share:/usr/local/share/:/usr/share/}"
      export MANPATH="$HOME/.nix-profile/share/man:/nix/var/nix/profiles/default/share/man:/usr/share/man"
    '';

    myPackages = pkgs.buildEnv {
      name = "my-packages";
      paths = [
        (runCommand "profile" {} ''
          mkdir -p $out/etc/profile.d
          cp ${myProfile} $out/etc/profile.d/my-profile.zsh
        '')
        nixfmt
        niv

        go

        jq

        kitty
        lf
        stow
        noisetorch
        helvum
        neofetch
        pavucontrol

        firefox
        chromium
        tdesktop
        discord
        github-desktop
      ];
      pathsToLink = [ "/share/man" "/share/doc" "/bin" "/etc" "/share/applications" ];
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
      pathsToLink = [
        "/share/man"
        "/share/doc"
        "/bin"
        "/etc"
        "/share/applications"
        "/share/backgrounds"
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };
  };
}
