let
  sleroq = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
  portable = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army";
  div = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqaD8lUj2IoSXbd+ZngR3w+7rKxS7DU/3CPo4jd9SE9 root@shared";
in
{
  "secrets/navidromeEnv".publicKeys = [
    sleroq
    portable
    div
  ];
  "secrets/tuwunelRegistrationToken".publicKeys = [
    sleroq
    portable
    div
  ];
  "secrets/tuwunelTurnSecret".publicKeys = [
    sleroq
    portable
    div
  ];
}
