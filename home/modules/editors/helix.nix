{ ... }:

{
  programs.helix = {
    enable = true;
    settings = {
      theme = "github_dark";
      editor = {
        shell = ["bash"];
        auto-save = true;
        lsp.display-messages = true;
        cursor-shape.insert = "bar";
        cursor-shape.select = "underline";
      };
    };
  };
}
