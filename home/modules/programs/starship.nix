{ lib, ... }:

{
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;

      format = lib.concatStrings [
        "$directory"
        "$git"
        # "$all" # Too much stuff

        "$fill"

        "$time"
        "$line_break"
        "$jobs"
        # "$battery" # TODO: only on laptop
        "$status"
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
