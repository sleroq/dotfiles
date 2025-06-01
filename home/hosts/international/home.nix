{ ... }:

{
  myHome = {
    programs = {
      obs.enable = true;
      chromium = {
        enable = true;
        unsafeWebGPU = true;
      };
      teams.enable = true;
    };
  };
}
