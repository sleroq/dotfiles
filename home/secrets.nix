let
  interplanetary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army";
  interplanetaryStateKey = "age1whlw5p3mmw6vkxh69sx6y6h3j88xj98d908zn2uvyvphfja9n9jqg20g52";
  idk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9Y+/pLBhAfjo/qKZqn7rTl4X3MBMdOuwW4sYo9pNi0 cantundo@pm.me";
  commonPublicKeys = [ interplanetary interplanetaryStateKey idk ];
in
{
  "secrets/flameshot-auth-token" = { publicKeys = commonPublicKeys; };
  "secrets/ssh-config" = { publicKeys = commonPublicKeys; };
  "secrets/gitconfig-wrk" = { publicKeys = commonPublicKeys; };
  "secrets/gitconfig-wrk-global" = { publicKeys = commonPublicKeys; };
  "secrets/gitignore-wrk" = { publicKeys = commonPublicKeys; };
  "secrets/allowed-signers" = { publicKeys = commonPublicKeys; };
  "secrets/allowed-signers-wrk" = { publicKeys = commonPublicKeys; };
}
