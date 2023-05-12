{ ... }:

{
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard";
      recolor = true;
      recolor-lightcolor = "#2f343f";
      recolor-keephue = true;
      # font = "Hack normal 9"
      inputbar-bg = "#404552";
      statusbar-bg = "#404552";
      default-bg = "#2f343f";
    };
  };
}
