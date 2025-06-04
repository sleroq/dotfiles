let
  sleroq = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
  cumserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNy4lHOvczy/vR4hf+uk6ciJGpkw5mqu3oC+9hTDbqf";
  commonPublicKeys = [ sleroq cumserver ];

  numberOfPasswords = 4;
  mailSecretBasePath = "secrets/mail/";
  passwordNamePrefix = "password";

  passwordNumbers = builtins.genList
    (index: index + 1)
    numberOfPasswords;

  passwordFilePaths = builtins.map
    (n: "${mailSecretBasePath}${passwordNamePrefix}${builtins.toString n}")
    passwordNumbers;

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
  };

in
  staticEntries // generatedPasswordEntries
