{
  bump-paseo-stack = {
    adoptId = "1c817bdf";
    name = "Dotfiles: bump Paseo stack";
    cron = "0 6 */3 * *";
    timezone = "UTC";
    provider = "pi";
    model = "openai/gpt-6.1-sol";
    thinkingOptionId = "low";
    cwd = "/home/paseo/projects/dotfiles";
    prompt = builtins.readFile ./paseo-stack-update.md;
    archiveOnFinish = true;
    isolation = "local";
  };
}
