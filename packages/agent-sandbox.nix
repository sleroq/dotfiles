{
  lib,
  dockerTools,
  buildEnv,
  writeText,
  runCommand,
  agent-jobs,
  pi,
  nodejs_24,
  bashInteractive,
  coreutils,
  git,
  curl,
  jq,
  findutils,
  ripgrep,
  cacert,
  nix,
  direnv,
  nixfmt,
  deadnix,
  nixf,
  ast-grep,
  callPackage,
  tree-sitter-grammars,
  fumo-pi ? null,
  fumoProxy ? false,
  substituters ? [ ],
  trustedPublicKeys ? [ ],
}:
let
  tools = buildEnv {
    name = "agent-sandbox-tools";
    paths = [
      agent-jobs
      pi
      nodejs_24
      bashInteractive
      coreutils
      git
      curl
      jq
      findutils
      ripgrep
      cacert
      nix
      direnv
      nixfmt
      deadnix
      nixf
      ast-grep
    ]
    ++ lib.optional (fumo-pi != null) fumo-pi;
    pathsToLink = [ "/bin" ];
  };
  nixConfig = writeText "nix.conf" ''
    sandbox = false
    build-users-group =
    experimental-features = nix-command flakes
    extra-substituters = ${lib.concatStringsSep " " substituters}
    extra-trusted-public-keys = ${lib.concatStringsSep " " trustedPublicKeys}
  '';
  bashEnv = writeText "agent-bash-env" ''
    _agent_jobs_direnv() {
      local exports
      exports=$(BASH_ENV= /bin/direnv export bash) || return
      eval "$exports"
    }
    cd() {
      builtin cd "$@" || return
      _agent_jobs_direnv || :
    }
    _agent_jobs_direnv
  '';
  piSettings = writeText "agent-pi-settings.json" (
    builtins.toJSON {
      extensions = lib.optional (fumo-pi != null) "${fumo-pi}/index.js";
      packages = lib.filter (lib.hasPrefix "npm:@ff-labs/pi-fff@") (builtins.fromJSON (
        builtins.readFile ../home/config/pi/agent/settings.json
      )).packages;
    }
  );
  piMcp = writeText "agent-pi-mcp.json" (
    builtins.toJSON {
      mcpServers = {
        exa = {
          command = "npx";
          args = [
            "-y"
            "exa-mcp-server@3.4.3"
          ];
          env = {
            EXA_API_KEY = "\${EXA_API_KEY}";
            NPM_CONFIG_REGISTRY = "https://registry.npmjs.org";
          };
          exposure = "direct";
          toolExposure.read_tools_list = "hidden";
        };
        grep.url = "https://mcp.grep.app";
      };
    }
  );
  svelteParser = callPackage ./tree-sitter-htmlx-svelte.nix { };
  sgConfig = writeText "agent-sgconfig.yml" (
    builtins.toJSON {
      ruleDirs = [ "${../home/config/ast-grep/rules/common}" ];
      customLanguages = {
        svelte = {
          libraryPath = "${svelteParser}/lib/tree-sitter-svelte";
          extensions = [ "svelte" ];
          languageSymbol = "tree_sitter_svelte";
        };
        zig = {
          libraryPath = "${tree-sitter-grammars.tree-sitter-zig}/parser";
          extensions = [ "zig" ];
          languageSymbol = "tree_sitter_zig";
          expandoChar = "_";
        };
      };
      languageInjections = [
        {
          hostLanguage = "svelte";
          rule.pattern = "<script>$CONTENT</script>";
          injected = "javascript";
        }
        {
          hostLanguage = "svelte";
          rule.pattern = ''<script lang="ts">$CONTENT</script>'';
          injected = "typescript";
        }
      ];
    }
  );
  root = runCommand "agent-sandbox-root" { } ''
    mkdir -p "$out/etc/nix" "$out/etc/ssl/certs" "$out/etc/agent-pi" "$out/etc/agent-jobs" "$out/bin"
    touch "$out/.envrc"
    ln -s ${bashEnv} "$out/etc/agent-jobs/bash-env"
    ln -s ${nixConfig} "$out/etc/nix/nix.conf"
    ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt "$out/etc/ssl/certs/ca-certificates.crt"
    ln -s ${bashInteractive}/bin/bash "$out/bin/sh"
    ln -s ${sgConfig} "$out/etc/sgconfig.yml"
    ln -s ${piSettings} "$out/etc/agent-pi/settings.json"
    ln -s ${piMcp} "$out/etc/agent-pi/mcp.json"
    ln -s ${../home/config/agents/AGENTS.md} "$out/etc/agent-pi/AGENTS.md"
    ln -s ${../home/config/agents/skills} "$out/etc/agent-pi/skills"
    printf '%s\n' 'agent:x:1000:1000:Agent:/home/agent:${lib.getExe bashInteractive}' > "$out/etc/passwd"
    printf '%s\n' 'agent:x:1000:' > "$out/etc/group"
  '';
in
dockerTools.buildLayeredImage {
  name = "agent-sandbox";
  tag = "mvp";
  contents = [
    tools
    root
  ];
  includeNixDB = true;
  fakeRootCommands = ''
    chown 1000:1000 ./nix ./nix/store
    chown -R 1000:1000 ./nix/var
    chmod u+rwx ./nix ./nix/store
    chmod -R u+rwX ./nix/var
  '';
  config = {
    Entrypoint = [ "/bin/agent-jobs" ];
    Cmd = [ "hold" ];
    Env = [
      "PATH=/bin"
      "HOME=/home/agent"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
    ]
    ++ (
      if fumoProxy then
        [
          "FUMO_BASE_URL=http://172.30.0.1:8789/v1"
          "FUMO_PI_KEY=non-secret-proxy-placeholder"
        ]
      else
        [ "FUMO_BASE_URL=https://fumo.cum.army/v1" ]
    );
    WorkingDir = "/workspace";
  };
}
