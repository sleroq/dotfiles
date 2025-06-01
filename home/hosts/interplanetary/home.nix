{ ... }:

{
  myHome = {
    editors = {
      zed.enable = true;
      cursor.enable = true;
    };
    gaming = {
      etterna.enable = true;
      osu.enable = true;
      minecraft.enable = true;
    };

    programs = {
      anytype = {
        enable = true;
        version = "0.46.8";
        hash = "sha256-lmMmGNXybJ33ODcSfguSPM05gun5CbKUcW3ZFo6jdVE=";
      };
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      teams.enable = true;
    };
  };
}
