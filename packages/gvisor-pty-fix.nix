{ gvisor }:
gvisor.overrideAttrs (
  old:
  let
    version = "${old.version}-pr17244";
  in
  {
    inherit version;
    patches = old.patches ++ [ ./gvisor-pty-fix.patch ];
    ldflags = old.ldflags ++ [ "-X=gvisor.dev/gvisor/runsc/version.version=release-${version}" ];
  }
)
