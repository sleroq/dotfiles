{
  config,
  inputs',
  lib,
  opts,
  pkgs,
  ...
}:

let
  cfg = config.myHome.programs.antigravity;
  json = pkgs.formats.json { };
  globalConfig = ".gemini/config";
  discoveryTools = [
    "view_file"
    "list_dir"
    "find_by_name"
    "grep_search"
  ];
  researchTools = discoveryTools ++ [
    "search_web"
    "read_url_content"
  ];
  agents = {
    itaru = {
      description = "Research agent for source code, documentation, examples, and best practices.";
      tools = researchTools;
    };
    kristina = {
      description = "Expert technical advisor for architecture, debugging, and review.";
      tools = researchTools ++ [ "run_command" ];
      adaptPrompt =
        lib.replaceStrings
          [
            "Use pi-fff's `grep` for workspace content and `find` for file discovery; use grep MCP for remote code search."
          ]
          [ "Use the available search tools for workspace content and file discovery." ];
    };
    suzuha = {
      description = "Implementation agent for bounded code changes, fixes, and verification.";
      tools = discoveryTools ++ [
        "run_command"
        "write_to_file"
        "replace_file_content"
        "multi_replace_file_content"
      ];
      adaptPrompt =
        lib.replaceStrings
          [
            "Use pi-fff's `grep` for content search and `find` for file discovery."
            "use grep MCP for remote code search."
          ]
          [
            "Use the available search tools for workspace content and file discovery."
            "use external sources when the task requires them."
          ];
    };
  };
  agentFile =
    name:
    {
      description,
      tools,
      adaptPrompt ? lib.id,
    }:
    let
      # Replace Pi's frontmatter, preserving any later Markdown separators.
      piAgent = builtins.readFile (../../config/pi/agent/agents + "/${name}.md");
      body = lib.concatStringsSep "\n---\n" (lib.drop 1 (lib.splitString "\n---\n" piAgent));
    in
    lib.nameValuePair "${globalConfig}/agents/${name}.md" {
      text = ''
        ---
        name: ${name}
        description: ${builtins.toJSON description}
        tools: ${builtins.toJSON tools}
        subagent: true
        ---
        ${adaptPrompt body}
      '';
    };
in
{
  options.myHome.programs.antigravity.enable = lib.mkEnableOption "Antigravity CLI";

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs'.llm-agents.packages.antigravity-cli
      pkgs.fff-mcp
    ];

    home.file = {
      ".gemini/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${opts.realConfigs}/agents/AGENTS.md";

      "${globalConfig}/skills.json".source = json.generate "antigravity-skills.json" {
        entries = [ { path = "${opts.realConfigs}/agents/skills"; } ];
      };

      "${globalConfig}/mcp_config.json".source = json.generate "antigravity-mcp.json" {
        mcpServers.fff.command = "${pkgs.fff-mcp}/bin/fff-mcp";
      };

      "${globalConfig}/rules/fff.md".text = ''
        ---
        trigger: always_on
        ---
        Prefer the FFF MCP tools for file and content search in Git repositories when
        available. Scope searches to a known directory when possible; never use FFF
        to index the entire /nix/store or an ancestor of it.
      '';
    }
    // lib.mapAttrs' agentFile agents;
  };
}
