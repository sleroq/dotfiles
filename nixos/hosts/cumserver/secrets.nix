let
  sleroq = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
  cumserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNy4lHOvczy/vR4hf+uk6ciJGpkw5mqu3oC+9hTDbqf";
in
{
  "secrets/matterbridge.toml".publicKeys = [ sleroq cumserver ];
}
