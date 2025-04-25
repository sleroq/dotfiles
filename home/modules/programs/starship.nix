{ lib, ... }:

{
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;

      format = lib.concatStrings [
        "$line_break"
        "$all"

        "$fill"

        "$time"
        "$line_break"
        "$jobs"
        "$battery"
        "$status"
        "$os"
        "$container"
        "$shell"
        "$character"
      ];

      time = {
        disabled = false;
        use_12hr = true;
        time_format = "%T %p";
      };
      fill = {
        symbol = " ";
      };
    };
  };
}
