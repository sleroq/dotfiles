inputs:
let
  # Pass flake inputs to overlay so we can use the sources pinned in flake.lock
  # instead of having to keep sha256 hashes in each package for src
  inherit inputs;
in
self: super: {
  # codeium = super.callPackage ./packages/codeium.nix { };
  # pyrit2 = super.callPackage ./packages/pyrit.nix { };
  obinskit = super.callPackage ./packages/obinskit.nix { };
  waybar-hyprland = super.waybar.overrideAttrs (oldAttrs: {
    postPatch = ''
      # use hyprctl to switch workspaces
      sed -i 's/zext_workspace_handle_v1_activate(workspace_handle_);/const std::string command = "hyprctl dispatch workspace " + name_;\n\tsystem(command.c_str());/g' src/modules/wlr/workspace_manager.cpp
    '';
    mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
  });
}
