let
  sleroq = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
  cumserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNy4lHOvczy/vR4hf+uk6ciJGpkw5mqu3oC+9hTDbqf";
  commonPublicKeys = [ sleroq cumserver ];

  numberOfMailPasswords = 5;
  mailSecretBasePath = "secrets/mail/";
  passwordNamePrefix = "password";

  mailPasswordNumbers = builtins.genList
    (index: index + 1)
    numberOfMailPasswords;

  passwordFilePaths = builtins.map
    (n: "${mailSecretBasePath}${passwordNamePrefix}${builtins.toString n}")
    mailPasswordNumbers;

  generatedPasswordEntries = builtins.listToAttrs (
    builtins.map
      (filePath: {
        name = filePath;
        value = { publicKeys = commonPublicKeys; };
      })
      passwordFilePaths
  );

  staticEntries = {
    "secrets/matterbridge.toml" = { publicKeys = commonPublicKeys; };
    "secrets/cf-fullchain.pem" = { publicKeys = commonPublicKeys; };
    "secrets/cf-privkey.pem" = { publicKeys = commonPublicKeys; };
    "secrets/grafanaPassword" = { publicKeys = commonPublicKeys; };
    "secrets/bayanEnv" = { publicKeys = commonPublicKeys; };
    "secrets/kopokaEnv" = { publicKeys = commonPublicKeys; };
    "secrets/navidromeEnv" = { publicKeys = commonPublicKeys; };
    "secrets/reactorEnv" = { publicKeys = commonPublicKeys; };
    "secrets/sieveEnv" = { publicKeys = commonPublicKeys; };
    "secrets/slushaEnv" = { publicKeys = commonPublicKeys; };
    "secrets/slushaConfig.js" = { publicKeys = commonPublicKeys; };
    "secrets/spoilerImagesEnv" = { publicKeys = commonPublicKeys; };
    "secrets/zefxiEnv" = { publicKeys = commonPublicKeys; };
    "secrets/marzbanMetricsEnv" = { publicKeys = commonPublicKeys; };
    "secrets/nodeExporter1Password" = { publicKeys = commonPublicKeys; };
    "secrets/nodeExporter3Password" = { publicKeys = commonPublicKeys; };
    "secrets/ziplineEnv" = { publicKeys = commonPublicKeys; };
    "secrets/resticMinecraftPassword" = { publicKeys = commonPublicKeys; };
  };

in
  staticEntries // generatedPasswordEntries
