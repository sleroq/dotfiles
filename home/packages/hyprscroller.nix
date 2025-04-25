{ lib
, pkg-config
, hyprland
, cmake
, fetchFromGitHub
,
}:

hyprland.stdenv.mkDerivation {
  pname = "hyprscroller";
  version = "0-unstable-2025-01-21";

  src = fetchFromGitHub {
    owner = "dawsers";
    repo = "hyprscroller";
    rev = "5b62ca58790f8c2961da79af95efa458f6a814fe";
    hash = "sha256-monOoefLpK2cUAPBlJlVt9BkoSELQmYVysj81zJ74i0=";

    # rev = "de8e4bf8c419d849b053299d67bd554ac3f5c231";
    # hash = "sha256-NZPCWWJuBF8xhg27puq9sHmEs1cxyPkiNpNCoHwqGcc=";
  };

  nativeBuildInputs = [ pkg-config cmake hyprland ];
  buildInputs = [ hyprland ] ++ hyprland.buildInputs;

  # Ensure the plugin is linked against the correct libraries
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  installPhase = ''
    mkdir -p $out/lib
    cp hyprscroller.so $out/lib/hyprscroller.so
  '';

  meta = {
    homepage = "https://github.com/dawsers/hyprscroller";
    description = "Hyprland layout plugin providing a scrolling layout like PaperWM";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ donovanglover ];
    platforms = lib.platforms.linux;
  };
}
