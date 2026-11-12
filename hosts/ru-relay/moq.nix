{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  packages = inputs.moq-box.packages.${system};
  releaseBinary =
    package: version: hash:
    package.overrideAttrs (old: {
      inherit version;
      src = pkgs.fetchurl {
        url = "https://github.com/moq-dev/moq/releases/download/${old.pname}-v${version}/${old.pname}-v${version}-x86_64-unknown-linux-gnu";
        inherit hash;
      };
    });
  moq = releaseBinary packages.moq "0.14.10" "sha256-mXzvUvE2fjXMUUutW+91w5IYKX+aHZcWbyaJZTu4sp4=";
in
{
  # Retain the pinned relay/auth module, updating only its release binaries.
  imports = [
    (import "${inputs.moq-box}/nix/module.nix" {
      self = inputs.moq-box // {
        packages.${system} = packages // {
          moq-relay =
            releaseBinary packages.moq-relay "0.17.10"
              "sha256-R7IJFmE0Hi/sNt+8wPUQ7acCt3FvxPTz2QGAa5ubjiM=";
          inherit moq;
        };
      };
    })
  ];

  config.systemd.services.moq-auth.serviceConfig.ExecStart = lib.mkForce (
    "${moq}/bin/moq auth serve"
    + " --listen 127.0.0.1:${toString config.services.moq-box.authPort}"
    + " --key /var/lib/moq-box/root.jwk --public-subscribe '**'"
  );

  # The pilot module also serves its own viewer; Broadcast Box now owns playback.
  options.services.caddy.virtualHosts = lib.mkOption {
    apply = lib.filterAttrs (
      name: _:
      !builtins.elem name [
        config.services.moq-box.domain
        "http://${config.services.moq-box.domain}"
      ]
    );
  };
}
