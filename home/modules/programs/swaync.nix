{ ... }:

{
  services.swaync = {
    enable = true;
    settings = {
      timeout = 3;
      timeout-low = 2;
      timeout-critical = 3;
    };
  };
}
